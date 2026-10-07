-- Esquema mínimo de la nueva aplicación. Ejecutar en Supabase SQL Editor.
begin;

alter table public.usuarios
  add column if not exists permisos jsonb not null default
    '{"ver_datos":true,"registrar_datos":true,"editar_datos":false,"respaldar_datos":false}'::jsonb;

create table if not exists public.registros (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descripcion text not null default '',
  creado_por uuid references public.usuarios(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create or replace function public.app_actor_valido(
  p_correo text, p_contrasena text, p_solo_admin boolean default false
) returns boolean
language sql security definer set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.usuarios u
    where lower(btrim(u.correo)) = lower(btrim(p_correo))
      and u.contrasena = p_contrasena
      and u.activo
      and (not p_solo_admin or lower(btrim(u.rol)) in ('admin','administrador','superadmin'))
  );
$$;

create or replace function public.app_iniciar_sesion(p_correo text, p_contrasena text)
returns jsonb language sql security definer set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'id', u.id, 'nombre', u.nombre, 'correo', u.correo, 'rol', u.rol,
    'admin', lower(btrim(u.rol)) in ('admin','administrador','superadmin'),
    'permisos', coalesce(u.permisos, '{}'::jsonb)
  )
  from public.usuarios u
  where lower(btrim(u.correo)) = lower(btrim(p_correo))
    and u.contrasena = p_contrasena and u.activo
  limit 1;
$$;

create or replace function public.app_listar_usuarios(p_actor_correo text, p_actor_contrasena text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then
    raise exception 'Solo un administrador puede gestionar usuarios';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', id, 'nombre', nombre, 'correo', correo, 'rol', rol,
    'activo', activo, 'permisos', permisos, 'numero_documento', numero_documento
  ) order by lower(nombre)) from public.usuarios), '[]'::jsonb);
end;
$$;

create or replace function public.app_guardar_usuario(
  p_actor_correo text, p_actor_contrasena text, p_id uuid,
  p_nombre text, p_correo text, p_contrasena text, p_activo boolean, p_permisos jsonb
) returns uuid language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then
    raise exception 'Solo un administrador puede gestionar usuarios';
  end if;
  if p_id is null then
    if nullif(btrim(p_contrasena), '') is null then raise exception 'La contraseña es obligatoria'; end if;
    insert into public.usuarios(nombre, correo, contrasena, rol, activo, permisos)
    values (btrim(p_nombre), lower(btrim(p_correo)), p_contrasena, 'usuario', p_activo,
      coalesce(p_permisos, '{}'::jsonb)) returning id into v_id;
  else
    update public.usuarios set nombre=btrim(p_nombre), correo=lower(btrim(p_correo)),
      activo=p_activo, permisos=coalesce(p_permisos, '{}'::jsonb),
      contrasena=case when nullif(btrim(p_contrasena), '') is null then contrasena else p_contrasena end
      where id=p_id and lower(btrim(rol)) not in ('admin','administrador','superadmin')
      returning id into v_id;
    if v_id is null then raise exception 'Usuario no encontrado o protegido'; end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.app_eliminar_usuario(p_actor_correo text, p_actor_contrasena text, p_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then raise exception 'Acceso denegado'; end if;
  delete from public.usuarios where id=p_id and lower(btrim(rol)) not in ('admin','administrador','superadmin');
  if not found then raise exception 'Usuario no encontrado o protegido'; end if;
end;
$$;

create or replace function public.app_listar_registros(p_actor_correo text, p_actor_contrasena text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user public.usuarios%rowtype;
begin
  select * into v_user from public.usuarios where lower(btrim(correo))=lower(btrim(p_actor_correo))
    and contrasena=p_actor_contrasena and activo;
  if not found then raise exception 'Sesión inválida'; end if;
  if lower(btrim(v_user.rol)) not in ('admin','administrador','superadmin')
    and not coalesce((v_user.permisos->>'ver_datos')::boolean, false)
    and not coalesce((v_user.permisos->>'registrar_datos')::boolean, false) then
    raise exception 'No tienes permiso para ver datos';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(r) order by r.creado_en desc) from public.registros r), '[]'::jsonb);
end;
$$;

create or replace function public.app_guardar_registro(
  p_actor_correo text, p_actor_contrasena text, p_id uuid, p_titulo text, p_descripcion text
) returns uuid language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user public.usuarios%rowtype; v_id uuid;
begin
  select * into v_user from public.usuarios where lower(btrim(correo))=lower(btrim(p_actor_correo))
    and contrasena=p_actor_contrasena and activo;
  if not found then raise exception 'Sesión inválida'; end if;
  if p_id is null then
    if lower(btrim(v_user.rol)) not in ('admin','administrador','superadmin')
      and not coalesce((v_user.permisos->>'registrar_datos')::boolean, false) then raise exception 'No tienes permiso para registrar'; end if;
    insert into public.registros(titulo, descripcion, creado_por)
      values (btrim(p_titulo), coalesce(p_descripcion,''), v_user.id) returning id into v_id;
  else
    if lower(btrim(v_user.rol)) not in ('admin','administrador','superadmin')
      and not coalesce((v_user.permisos->>'editar_datos')::boolean, false) then raise exception 'No tienes permiso para editar'; end if;
    update public.registros set titulo=btrim(p_titulo), descripcion=coalesce(p_descripcion,''), actualizado_en=now()
      where id=p_id returning id into v_id;
    if v_id is null then raise exception 'Registro no encontrado'; end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.app_respaldo_registros(p_actor_correo text, p_actor_contrasena text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user public.usuarios%rowtype;
begin
  select * into v_user from public.usuarios where lower(btrim(correo))=lower(btrim(p_actor_correo))
    and contrasena=p_actor_contrasena and activo;
  if not found then raise exception 'Sesión inválida'; end if;
  if lower(btrim(v_user.rol)) not in ('admin','administrador','superadmin')
    and not coalesce((v_user.permisos->>'respaldar_datos')::boolean, false) then raise exception 'No tienes permiso de respaldo'; end if;
  return coalesce((select jsonb_agg(to_jsonb(r) order by r.creado_en) from public.registros r), '[]'::jsonb);
end;
$$;

create or replace function public.app_eliminar_registros(p_actor_correo text, p_actor_contrasena text)
returns integer language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_user public.usuarios%rowtype; v_count integer;
begin
  select * into v_user from public.usuarios where lower(btrim(correo))=lower(btrim(p_actor_correo))
    and contrasena=p_actor_contrasena and activo;
  if not found then raise exception 'Sesión inválida'; end if;
  if lower(btrim(v_user.rol)) not in ('admin','administrador','superadmin')
    and not coalesce((v_user.permisos->>'respaldar_datos')::boolean, false) then raise exception 'No tienes permiso para eliminar'; end if;
  delete from public.registros;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.app_actor_valido(text,text,boolean) from public;
revoke all on function public.app_iniciar_sesion(text,text) from public;
revoke all on function public.app_listar_usuarios(text,text) from public;
revoke all on function public.app_guardar_usuario(text,text,uuid,text,text,text,boolean,jsonb) from public;
revoke all on function public.app_eliminar_usuario(text,text,uuid) from public;
revoke all on function public.app_listar_registros(text,text) from public;
revoke all on function public.app_guardar_registro(text,text,uuid,text,text) from public;
revoke all on function public.app_respaldo_registros(text,text) from public;
revoke all on function public.app_eliminar_registros(text,text) from public;

grant execute on function public.app_iniciar_sesion(text,text) to anon, authenticated;
grant execute on function public.app_listar_usuarios(text,text) to anon, authenticated;
grant execute on function public.app_guardar_usuario(text,text,uuid,text,text,text,boolean,jsonb) to anon, authenticated;
grant execute on function public.app_eliminar_usuario(text,text,uuid) to anon, authenticated;
grant execute on function public.app_listar_registros(text,text) to anon, authenticated;
grant execute on function public.app_guardar_registro(text,text,uuid,text,text) to anon, authenticated;
grant execute on function public.app_respaldo_registros(text,text) to anon, authenticated;
grant execute on function public.app_eliminar_registros(text,text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
