-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Resultados de Pruebas de Selección (versión 2)
--  Deja la tabla resultados_pruebas y sus funciones RPC listas para la app.
--  Usa la misma validación de sesión que app_setup.sql (app_actor_valido):
--  correo sin distinguir mayúsculas, contraseña tal como está en usuarios
--  y administrador según la columna rol.
--  Se puede ejecutar varias veces sin problema.
-- ══════════════════════════════════════════════════════════════════════════
begin;

-- ─── 1. Columnas que la app necesita ─────────────────────────────────────
alter table public.resultados_pruebas
  add column if not exists genero text,
  add column if not exists competencias jsonb not null default '{}'::jsonb,
  add column if not exists actualizado_en timestamptz not null default now();

-- Las columnas de calidad guardan 'ok' o '1' desde la app → texto.
alter table public.resultados_pruebas
  alter column pin_board_calidad_t1 type text using pin_board_calidad_t1::text,
  alter column pin_board_calidad_t2 type text using pin_board_calidad_t2::text,
  alter column destreza_fina_calidad_t1 type text using destreza_fina_calidad_t1::text,
  alter column destreza_fina_calidad_t2 type text using destreza_fina_calidad_t2::text,
  alter column speed_stack_calidad_t1 type text using speed_stack_calidad_t1::text,
  alter column speed_stack_calidad_t2 type text using speed_stack_calidad_t2::text,
  alter column habilidad_motora_gruesa_calidad_t1 type text using habilidad_motora_gruesa_calidad_t1::text,
  alter column prueba_campo_calidad_t1 type text using prueba_campo_calidad_t1::text,
  alter column concentracion_conteo_calidad_t1 type text using concentracion_conteo_calidad_t1::text;

create index if not exists resultados_pruebas_cedula_idx on public.resultados_pruebas (cedula);
create index if not exists resultados_pruebas_creado_idx on public.resultados_pruebas (creado_en desc);

-- La tabla solo se usa a través de las funciones (security definer).
alter table public.resultados_pruebas enable row level security;

-- ─── 2. Helper: obtiene el usuario de la sesión o lanza error ────────────
create or replace function public.app_actor(p_correo text, p_contrasena text)
returns public.usuarios
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype;
begin
  select * into v from public.usuarios u
   where lower(btrim(u.correo)) = lower(btrim(p_correo))
     and u.contrasena = p_contrasena
     and u.activo
   limit 1;
  if not found then raise exception 'Sesión inválida'; end if;
  return v;
end;
$$;

create or replace function public.app_es_admin(p_rol text)
returns boolean language sql immutable
as $$ select lower(btrim(coalesce(p_rol, ''))) in ('admin','administrador','superadmin') $$;

-- ─── 3. Listar resultados ────────────────────────────────────────────────
drop function if exists public.app_listar_resultados(text, text);
create function public.app_listar_resultados(p_actor_correo text, p_actor_contrasena text)
returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'ver_datos')::boolean, false)
     and not coalesce((v.permisos->>'registrar_datos')::boolean, false) then
    raise exception 'No tienes permiso para ver datos';
  end if;
  return coalesce(
    (select jsonb_agg(to_jsonb(r) order by r.creado_en desc) from public.resultados_pruebas r),
    '[]'::jsonb);
end;
$$;

-- ─── 4. Guardar (insertar o actualizar) ──────────────────────────────────
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p
           join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'app_guardar_resultado'
  loop
    execute 'drop function ' || f.sig;
  end loop;
end $$;

create function public.app_guardar_resultado(
  p_actor_correo text,
  p_actor_contrasena text,
  p_id uuid default null,
  p_fecha date default current_date,
  p_nombre text default null,
  p_apellido text default null,
  p_cedula text default null,
  p_area text default null,
  p_genero text default null,
  p_formador text default null,
  p_proceso text default null,
  p_lider_prueba text default null,
  p_pin_board_destreza_t1 numeric default null,
  p_pin_board_destreza_t2 numeric default null,
  p_pin_board_calidad_t1 text default null,
  p_pin_board_calidad_t2 text default null,
  p_destreza_fina_destreza_t1 numeric default null,
  p_destreza_fina_destreza_t2 numeric default null,
  p_destreza_fina_calidad_t1 text default null,
  p_destreza_fina_calidad_t2 text default null,
  p_speed_stack_destreza_t1 numeric default null,
  p_speed_stack_destreza_t2 numeric default null,
  p_speed_stack_calidad_t1 text default null,
  p_speed_stack_calidad_t2 text default null,
  p_fit_brain_velocidad_t1 numeric default null,
  p_fit_brain_velocidad_t2 numeric default null,
  p_fit_brain_porcentaje_acierto_t1 numeric default null,
  p_fit_brain_porcentaje_acierto_t2 numeric default null,
  p_habilidad_motora_gruesa_destreza_t1 numeric default null,
  p_habilidad_motora_gruesa_calidad_t1 text default null,
  p_prueba_campo_destreza_t1 numeric default null,
  p_prueba_campo_calidad_t1 text default null,
  p_concentracion_conteo_destreza_t1 numeric default null,
  p_concentracion_conteo_calidad_t1 text default null,
  p_suma numeric default null,
  p_resta numeric default null,
  p_multiplicacion numeric default null,
  p_division numeric default null,
  p_competencias jsonb default null
)
returns uuid
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype; v_id uuid;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);

  if nullif(btrim(p_nombre), '') is null or nullif(btrim(p_cedula), '') is null then
    raise exception 'Nombre y cédula son obligatorios';
  end if;

  if p_id is null then
    if not public.app_es_admin(v.rol)
       and not coalesce((v.permisos->>'registrar_datos')::boolean, false) then
      raise exception 'No tienes permiso para registrar';
    end if;
    insert into public.resultados_pruebas (
      fecha, nombre, apellido, cedula, area, genero, formador, proceso, lider_prueba,
      pin_board_destreza_t1, pin_board_destreza_t2, pin_board_calidad_t1, pin_board_calidad_t2,
      destreza_fina_destreza_t1, destreza_fina_destreza_t2, destreza_fina_calidad_t1, destreza_fina_calidad_t2,
      speed_stack_destreza_t1, speed_stack_destreza_t2, speed_stack_calidad_t1, speed_stack_calidad_t2,
      fit_brain_velocidad_t1, fit_brain_velocidad_t2, fit_brain_porcentaje_acierto_t1, fit_brain_porcentaje_acierto_t2,
      habilidad_motora_gruesa_destreza_t1, habilidad_motora_gruesa_calidad_t1,
      prueba_campo_destreza_t1, prueba_campo_calidad_t1,
      concentracion_conteo_destreza_t1, concentracion_conteo_calidad_t1,
      suma, resta, multiplicacion, division, competencias, registrado_por
    ) values (
      coalesce(p_fecha, current_date), btrim(p_nombre), btrim(p_apellido), btrim(p_cedula),
      p_area, p_genero, p_formador, p_proceso, p_lider_prueba,
      p_pin_board_destreza_t1, p_pin_board_destreza_t2, p_pin_board_calidad_t1, p_pin_board_calidad_t2,
      p_destreza_fina_destreza_t1, p_destreza_fina_destreza_t2, p_destreza_fina_calidad_t1, p_destreza_fina_calidad_t2,
      p_speed_stack_destreza_t1, p_speed_stack_destreza_t2, p_speed_stack_calidad_t1, p_speed_stack_calidad_t2,
      p_fit_brain_velocidad_t1, p_fit_brain_velocidad_t2, p_fit_brain_porcentaje_acierto_t1, p_fit_brain_porcentaje_acierto_t2,
      p_habilidad_motora_gruesa_destreza_t1, p_habilidad_motora_gruesa_calidad_t1,
      p_prueba_campo_destreza_t1, p_prueba_campo_calidad_t1,
      p_concentracion_conteo_destreza_t1, p_concentracion_conteo_calidad_t1,
      p_suma, p_resta, p_multiplicacion, p_division,
      coalesce(p_competencias, '{}'::jsonb), v.id
    ) returning id into v_id;
  else
    if not public.app_es_admin(v.rol)
       and not coalesce((v.permisos->>'editar_datos')::boolean, false) then
      raise exception 'No tienes permiso para editar';
    end if;
    update public.resultados_pruebas set
      fecha = coalesce(p_fecha, fecha), nombre = btrim(p_nombre), apellido = btrim(p_apellido),
      cedula = btrim(p_cedula), area = p_area, genero = p_genero, formador = p_formador,
      proceso = p_proceso, lider_prueba = p_lider_prueba,
      pin_board_destreza_t1 = p_pin_board_destreza_t1, pin_board_destreza_t2 = p_pin_board_destreza_t2,
      pin_board_calidad_t1 = p_pin_board_calidad_t1, pin_board_calidad_t2 = p_pin_board_calidad_t2,
      destreza_fina_destreza_t1 = p_destreza_fina_destreza_t1, destreza_fina_destreza_t2 = p_destreza_fina_destreza_t2,
      destreza_fina_calidad_t1 = p_destreza_fina_calidad_t1, destreza_fina_calidad_t2 = p_destreza_fina_calidad_t2,
      speed_stack_destreza_t1 = p_speed_stack_destreza_t1, speed_stack_destreza_t2 = p_speed_stack_destreza_t2,
      speed_stack_calidad_t1 = p_speed_stack_calidad_t1, speed_stack_calidad_t2 = p_speed_stack_calidad_t2,
      fit_brain_velocidad_t1 = p_fit_brain_velocidad_t1, fit_brain_velocidad_t2 = p_fit_brain_velocidad_t2,
      fit_brain_porcentaje_acierto_t1 = p_fit_brain_porcentaje_acierto_t1,
      fit_brain_porcentaje_acierto_t2 = p_fit_brain_porcentaje_acierto_t2,
      habilidad_motora_gruesa_destreza_t1 = p_habilidad_motora_gruesa_destreza_t1,
      habilidad_motora_gruesa_calidad_t1 = p_habilidad_motora_gruesa_calidad_t1,
      prueba_campo_destreza_t1 = p_prueba_campo_destreza_t1, prueba_campo_calidad_t1 = p_prueba_campo_calidad_t1,
      concentracion_conteo_destreza_t1 = p_concentracion_conteo_destreza_t1,
      concentracion_conteo_calidad_t1 = p_concentracion_conteo_calidad_t1,
      suma = p_suma, resta = p_resta, multiplicacion = p_multiplicacion, division = p_division,
      competencias = coalesce(p_competencias, competencias),
      actualizado_en = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then raise exception 'Resultado no encontrado'; end if;
  end if;
  return v_id;
end;
$$;

-- ─── 5. Respaldo y eliminación de resultados ─────────────────────────────
create or replace function public.app_respaldo_resultados(p_actor_correo text, p_actor_contrasena text)
returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'respaldar_datos')::boolean, false) then
    raise exception 'No tienes permiso de respaldo';
  end if;
  return coalesce(
    (select jsonb_agg(to_jsonb(r) order by r.creado_en) from public.resultados_pruebas r),
    '[]'::jsonb);
end;
$$;

create or replace function public.app_eliminar_resultados(p_actor_correo text, p_actor_contrasena text)
returns integer
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v public.usuarios%rowtype; v_count integer;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'respaldar_datos')::boolean, false) then
    raise exception 'No tienes permiso para eliminar';
  end if;
  delete from public.resultados_pruebas where true;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ─── 6. Permisos ─────────────────────────────────────────────────────────
revoke all on function public.app_actor(text, text) from public, anon, authenticated;
revoke all on function public.app_listar_resultados(text, text) from public;
revoke all on function public.app_respaldo_resultados(text, text) from public;
revoke all on function public.app_eliminar_resultados(text, text) from public;
revoke all on function public.app_guardar_resultado from public;

grant execute on function public.app_listar_resultados(text, text) to anon, authenticated;
grant execute on function public.app_guardar_resultado to anon, authenticated;
grant execute on function public.app_respaldo_resultados(text, text) to anon, authenticated;
grant execute on function public.app_eliminar_resultados(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
