-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Historial paginado de Resultados de Pruebas
--  Filtros: rango de fechas, número de documento (cédula), estado de la
--  Prueba de Campo ('completo' | 'pendiente') y resultado final
--  ('Aprobado' | 'Reprobado' | 'sin_calcular').
--  Devuelve: { total, completos, pendientes, aprobados, desaprobados,
--              sin_calcular, filas: [...] }
--  Requiere resultados_v2.sql y resultados_niveles.sql.
-- ══════════════════════════════════════════════════════════════════════════
begin;

create index if not exists resultados_pruebas_fecha_idx
  on public.resultados_pruebas (fecha desc, creado_en desc);

create or replace function public.app_campo_completo(r public.resultados_pruebas)
returns boolean language sql immutable
as $$
  select r.prueba_campo_destreza_t1 is not null
     and nullif(btrim(coalesce(r.prueba_campo_calidad_t1, '')), '') is not null
$$;

drop function if exists public.app_listar_resultados_pag(text, text, date, date, text, text, integer, integer);
drop function if exists public.app_listar_resultados_pag(text, text, date, date, text, text, integer, integer, text);
create function public.app_listar_resultados_pag(
  p_actor_correo text,
  p_actor_contrasena text,
  p_desde date default null,
  p_hasta date default null,
  p_cedula text default null,
  p_estado_campo text default null,   -- 'completo' | 'pendiente' | null
  p_limite integer default 20,
  p_offset integer default 0,
  p_resultado text default null       -- 'Aprobado' | 'Reprobado' | 'sin_calcular' | null
)
returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $$
declare
  v public.usuarios%rowtype;
  v_cedula text := nullif(btrim(coalesce(p_cedula, '')), '');
  v_limite integer := least(greatest(coalesce(p_limite, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_res jsonb;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'ver_datos')::boolean, false)
     and not coalesce((v.permisos->>'registrar_datos')::boolean, false) then
    raise exception 'No tienes permiso para ver datos';
  end if;

  with base as (
    select r.*, public.app_campo_completo(r) as campo_completo
      from public.resultados_pruebas r
     where (p_desde is null or r.fecha >= p_desde)
       and (p_hasta is null or r.fecha <= p_hasta)
       and (v_cedula is null or r.cedula ilike '%' || v_cedula || '%')
  ),
  filtrado as (
    select * from base
     where (p_estado_campo is null
            or (p_estado_campo = 'completo' and campo_completo)
            or (p_estado_campo = 'pendiente' and not campo_completo))
       and (p_resultado is null
            or (p_resultado = 'sin_calcular' and resultado is null)
            or resultado = p_resultado)
  ),
  pagina as (
    select * from filtrado
     order by fecha desc, creado_en desc
     limit v_limite offset v_offset
  )
  select jsonb_build_object(
    'total', (select count(*) from filtrado),
    'completos', (select count(*) from base where campo_completo),
    'pendientes', (select count(*) from base where not campo_completo),
    'aprobados', (select count(*) from base where resultado = 'Aprobado'),
    'desaprobados', (select count(*) from base where resultado = 'Reprobado'),
    'sin_calcular', (select count(*) from base where resultado is null),
    'filas', coalesce((select jsonb_agg(to_jsonb(p) order by p.fecha desc, p.creado_en desc) from pagina p), '[]'::jsonb)
  ) into v_res;

  return v_res;
end;
$$;

revoke all on function public.app_listar_resultados_pag(text, text, date, date, text, text, integer, integer, text) from public;
grant execute on function public.app_listar_resultados_pag(text, text, date, date, text, text, integer, integer, text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
