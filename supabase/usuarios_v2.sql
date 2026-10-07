-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Módulo de Usuarios (versión 2)
--  * Permite editar también a los administradores (nombre, correo,
--    documento, contraseña) y asignar el rol Usuario / Administrador.
--  * Protecciones: no puedes desactivarte, quitarte el rol de administrador
--    ni eliminarte a ti mismo, y siempre debe quedar un administrador activo.
--  * Mensajes claros para correo o documento repetidos.
--  Requiere app_setup.sql (app_actor_valido).
-- ══════════════════════════════════════════════════════════════════════════
begin;

create unique index if not exists usuarios_numero_documento_key
  on public.usuarios (numero_documento)
  where numero_documento is not null and btrim(numero_documento) <> '';

create or replace function public.app_listar_usuarios(p_actor_correo text, p_actor_contrasena text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then
    raise exception 'Solo un administrador puede gestionar usuarios';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', id, 'nombre', nombre, 'correo', correo, 'rol', rol,
    'admin', lower(btrim(rol)) in ('admin','administrador','superadmin'),
    'activo', activo, 'permisos', permisos, 'numero_documento', numero_documento,
    'creado_en', creado_en
  ) order by lower(nombre)) from public.usuarios), '[]'::jsonb);
end;
$$;

drop function if exists public.app_guardar_usuario(text, text, uuid, text, text, text, boolean, jsonb);
drop function if exists public.app_guardar_usuario(text, text, uuid, text, text, text, boolean, jsonb, text, text);
create function public.app_guardar_usuario(
  p_actor_correo text, p_actor_contrasena text, p_id uuid,
  p_nombre text, p_correo text, p_contrasena text, p_activo boolean, p_permisos jsonb,
  p_rol text default null,               -- 'usuario' | 'admin' (null = no cambia)
  p_numero_documento text default null
) returns uuid language plpgsql security definer set search_path = pg_catalog, public
as $$
declare
  v_actor public.usuarios%rowtype;
  v_actual public.usuarios%rowtype;
  v_id uuid;
  v_rol text;
  v_correo text := lower(btrim(coalesce(p_correo, '')));
  v_doc text := nullif(btrim(coalesce(p_numero_documento, '')), '');
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then
    raise exception 'Solo un administrador puede gestionar usuarios';
  end if;
  select * into v_actor from public.usuarios
   where lower(btrim(correo)) = lower(btrim(p_actor_correo)) limit 1;

  if nullif(btrim(coalesce(p_nombre, '')), '') is null then
    raise exception 'El nombre es obligatorio';
  end if;
  if v_correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'El correo no es válido';
  end if;
  if exists (select 1 from public.usuarios
              where lower(btrim(correo)) = v_correo and id is distinct from p_id) then
    raise exception 'Ya existe un usuario con ese correo';
  end if;
  if v_doc is not null and exists (select 1 from public.usuarios
              where btrim(numero_documento) = v_doc and id is distinct from p_id) then
    raise exception 'Ya existe un usuario con ese número de documento';
  end if;
  if p_contrasena is not null and btrim(p_contrasena) <> '' and length(p_contrasena) < 4 then
    raise exception 'La contraseña debe tener al menos 4 caracteres';
  end if;

  v_rol := case lower(btrim(coalesce(p_rol, '')))
             when 'admin' then 'ADMIN'
             when 'administrador' then 'ADMIN'
             when 'usuario' then 'usuario'
             else null end;

  if p_id is null then
    if nullif(btrim(coalesce(p_contrasena, '')), '') is null then
      raise exception 'La contraseña es obligatoria';
    end if;
    insert into public.usuarios(nombre, correo, contrasena, rol, activo, permisos, numero_documento)
    values (btrim(p_nombre), v_correo, p_contrasena, coalesce(v_rol, 'usuario'),
            coalesce(p_activo, true), coalesce(p_permisos, '{}'::jsonb), v_doc)
    returning id into v_id;
  else
    select * into v_actual from public.usuarios where id = p_id;
    if not found then raise exception 'Usuario no encontrado'; end if;

    -- Protecciones sobre la propia cuenta
    if v_actual.id = v_actor.id then
      if coalesce(p_activo, true) = false then
        raise exception 'No puedes desactivar tu propia cuenta';
      end if;
      if v_rol = 'usuario' then
        raise exception 'No puedes quitarte el rol de administrador';
      end if;
    end if;

    -- Siempre debe quedar al menos un administrador activo
    if public.app_es_admin(v_actual.rol) and v_actual.activo
       and (v_rol = 'usuario' or coalesce(p_activo, true) = false)
       and (select count(*) from public.usuarios
             where activo and public.app_es_admin(rol) and id <> v_actual.id) = 0 then
      raise exception 'Debe quedar al menos un administrador activo';
    end if;

    update public.usuarios set
      nombre = btrim(p_nombre),
      correo = v_correo,
      activo = coalesce(p_activo, activo),
      permisos = coalesce(p_permisos, permisos),
      rol = coalesce(v_rol, rol),
      numero_documento = v_doc,
      contrasena = case when nullif(btrim(coalesce(p_contrasena, '')), '') is null
                        then contrasena else p_contrasena end
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

create or replace function public.app_eliminar_usuario(p_actor_correo text, p_actor_contrasena text, p_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_actor public.usuarios%rowtype; v_obj public.usuarios%rowtype;
begin
  if not public.app_actor_valido(p_actor_correo, p_actor_contrasena, true) then
    raise exception 'Acceso denegado';
  end if;
  select * into v_actor from public.usuarios
   where lower(btrim(correo)) = lower(btrim(p_actor_correo)) limit 1;
  select * into v_obj from public.usuarios where id = p_id;
  if not found then raise exception 'Usuario no encontrado'; end if;
  if v_obj.id = v_actor.id then raise exception 'No puedes eliminar tu propia cuenta'; end if;
  if public.app_es_admin(v_obj.rol)
     and (select count(*) from public.usuarios
           where activo and public.app_es_admin(rol) and id <> v_obj.id) = 0 then
    raise exception 'Debe quedar al menos un administrador activo';
  end if;
  -- Los resultados que registró se conservan (registrado_por queda vacío).
  update public.resultados_pruebas set registrado_por = null where registrado_por = p_id;
  delete from public.usuarios where id = p_id;
end;
$$;

revoke all on function public.app_guardar_usuario(text, text, uuid, text, text, text, boolean, jsonb, text, text) from public;
grant execute on function public.app_guardar_usuario(text, text, uuid, text, text, text, boolean, jsonb, text, text) to anon, authenticated;
revoke all on function public.app_eliminar_usuario(text, text, uuid) from public;
grant execute on function public.app_eliminar_usuario(text, text, uuid) to anon, authenticated;
revoke all on function public.app_listar_usuarios(text, text) from public;
grant execute on function public.app_listar_usuarios(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
