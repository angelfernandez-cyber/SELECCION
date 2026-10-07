-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Niveles calculados (vista Proceso) para el PDF
--  Guarda junto a cada resultado lo que muestra la pestaña Proceso:
--    niveles            jsonb   → por prueba: tiempo, nivel por tiempo,
--                                 calidad, baja por calidad, nivel final,
--                                 % acierto (Fit Brain), actitud (puntos y
--                                 nivel); y un resumen con suma y cantidad.
--    promedio           numeric → (niveles de pruebas + actitud) / cantidad
--    resultado          text    → 'Aprobado' (promedio >= 3) | 'Reprobado'
--    prueba_campo_tipo  text    → Encanaste | Clasificación | Barridos
--  Requiere resultados_v2.sql (app_actor, app_es_admin).
-- ══════════════════════════════════════════════════════════════════════════
begin;

alter table public.resultados_pruebas
  add column if not exists niveles jsonb not null default '{}'::jsonb,
  add column if not exists promedio numeric(4,2),
  add column if not exists resultado text,
  add column if not exists prueba_campo_tipo text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'resultados_pruebas_resultado_chk'
  ) then
    alter table public.resultados_pruebas
      add constraint resultados_pruebas_resultado_chk
      check (resultado is null or resultado in ('Aprobado', 'Reprobado'));
  end if;
end $$;

create or replace function public.app_guardar_niveles(
  p_actor_correo text,
  p_actor_contrasena text,
  p_id uuid,
  p_niveles jsonb,
  p_promedio numeric,
  p_resultado text,
  p_prueba_campo_tipo text
)
returns void
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'registrar_datos')::boolean, false)
     and not coalesce((v.permisos->>'editar_datos')::boolean, false) then
    raise exception 'No tienes permiso para guardar niveles';
  end if;

  update public.resultados_pruebas set
    niveles = coalesce(p_niveles, '{}'::jsonb),
    promedio = p_promedio,
    resultado = p_resultado,
    prueba_campo_tipo = p_prueba_campo_tipo,
    actualizado_en = now()
  where id = p_id;
  if not found then raise exception 'Resultado no encontrado'; end if;
end;
$$;

revoke all on function public.app_guardar_niveles(text, text, uuid, jsonb, numeric, text, text) from public;
grant execute on function public.app_guardar_niveles(text, text, uuid, jsonb, numeric, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
