-- Restaurar resultados desde un respaldo JSON (módulo Respaldo).
-- Inserta solo los registros cuyo id NO existe; los que ya están se omiten.
create or replace function public.app_restaurar_resultados(
  p_actor_correo text,
  p_actor_contrasena text,
  p_datos jsonb
)
returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare
  v public.usuarios%rowtype;
  v_cols text;
  v_total integer;
  v_insertados integer;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'respaldar_datos')::boolean, false) then
    raise exception 'No tienes permiso para restaurar respaldos';
  end if;

  if p_datos is null or jsonb_typeof(p_datos) <> 'array' then
    raise exception 'El archivo no tiene una lista de resultados válida';
  end if;
  v_total := jsonb_array_length(p_datos);

  -- Solo columnas que se pueden insertar (sin columnas generadas).
  select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position)
    into v_cols
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'resultados_pruebas'
    and c.is_generated = 'NEVER'
    and coalesce(c.identity_generation, '') <> 'ALWAYS';

  execute format(
    'insert into public.resultados_pruebas (%1$s)
       select %1$s from jsonb_populate_recordset(null::public.resultados_pruebas, $1) s
       where s.id is not null
         and not exists (select 1 from public.resultados_pruebas t where t.id = s.id)',
    v_cols)
  using p_datos;
  get diagnostics v_insertados = row_count;

  return jsonb_build_object(
    'total', v_total,
    'insertados', v_insertados,
    'omitidos', v_total - v_insertados
  );
end;
$$;

grant execute on function public.app_restaurar_resultados(text, text, jsonb) to anon, authenticated;
