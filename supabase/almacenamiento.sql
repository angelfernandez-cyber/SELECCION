-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Almacenamiento usado en Supabase
--  app_almacenamiento(correo, contraseña) → { plan, limite_bytes, usado_bytes,
--    disponible_bytes, resultados_bytes, resultados }
--  Plan Free de Supabase: 500 MB de base de datos por proyecto. Si cambias de
--  plan, ajusta v_limite.
-- ══════════════════════════════════════════════════════════════════════════
create or replace function public.app_almacenamiento(p_actor_correo text, p_actor_contrasena text)
returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $$
declare
  v public.usuarios%rowtype;
  v_limite bigint := 500::bigint * 1024 * 1024;   -- 500 MB (plan Free)
  v_usado bigint := pg_database_size(current_database());
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'respaldar_datos')::boolean, false) then
    raise exception 'No tienes permiso de respaldo';
  end if;
  return jsonb_build_object(
    'plan', 'Free',
    'limite_bytes', v_limite,
    'usado_bytes', v_usado,
    'disponible_bytes', greatest(v_limite - v_usado, 0),
    'resultados_bytes', pg_total_relation_size('public.resultados_pruebas'),
    'resultados', (select count(*) from public.resultados_pruebas),
    'bytes_por_resultado', (select coalesce(avg(pg_column_size(r.*)), 0)::int from public.resultados_pruebas r)
  );
end;
$$;

revoke all on function public.app_almacenamiento(text, text) from public;
grant execute on function public.app_almacenamiento(text, text) to anon, authenticated;
notify pgrst, 'reload schema';
