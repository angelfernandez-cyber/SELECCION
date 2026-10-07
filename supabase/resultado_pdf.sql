-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Datos de un resultado organizados como la plantilla PDF
--  ("Pruebas de Selección" – Gestión Humana).
--  app_resultado_pdf(correo, contraseña, id) → jsonb con las secciones:
--    informacion_general, calificacion_final, pruebas (T1/T2 destreza y
--    calidad + mejor tiempo), fit_brain, operaciones, competencias
--    (6 valoraciones × 7 columnas + TOTAL), destreza_y_calidad, actitud.
--  Cargo = área. Prueba adicional = prueba de campo (solo T1).
--  Requiere resultados_v2.sql y resultados_niveles.sql.
-- ══════════════════════════════════════════════════════════════════════════
begin;

create or replace function public.app_resultado_pdf(
  p_actor_correo text,
  p_actor_contrasena text,
  p_id uuid
)
returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $$
declare
  v public.usuarios%rowtype;
  r public.resultados_pruebas%rowtype;
  n jsonb;
  comps text[] := array[
    'Seguimiento de instrucciones', 'Comunicación Efectiva', 'Atención al detalle',
    'Flexibilidad', 'Orientación al logro', 'Tolerancia a la presión'];
  cols text[] := array[
    'pin_board', 'destreza_fina', 'speed_stack', 'concentracion_conteo',
    'fit_brain', 'habilidad_motora_gruesa', 'prueba_campo'];
  filas jsonb := '[]'::jsonb;
  totales jsonb := '{}'::jsonb;
  c text; k text; fila jsonb; val jsonb; tot int;
begin
  v := public.app_actor(p_actor_correo, p_actor_contrasena);
  if not public.app_es_admin(v.rol)
     and not coalesce((v.permisos->>'ver_datos')::boolean, false)
     and not coalesce((v.permisos->>'registrar_datos')::boolean, false) then
    raise exception 'No tienes permiso para ver datos';
  end if;

  select * into r from public.resultados_pruebas where id = p_id;
  if not found then raise exception 'Resultado no encontrado'; end if;
  n := coalesce(r.niveles->'pruebas', '{}'::jsonb);

  -- Tabla de valoración de competencias (0, 1, 2) y su total por prueba.
  foreach c in array comps loop
    fila := jsonb_build_object('valoracion', c);
    foreach k in array cols loop
      val := r.competencias->k->c;
      fila := fila || jsonb_build_object(k, val);
    end loop;
    filas := filas || jsonb_build_array(fila);
  end loop;
  foreach k in array cols loop
    select sum((e.value)::int) into tot
      from jsonb_each_text(coalesce(r.competencias->k, '{}'::jsonb)) e
     where e.value ~ '^[0-9]+$';
    totales := totales || jsonb_build_object(k, tot);
  end loop;

  return jsonb_build_object(
    'id', r.id,
    'informacion_general', jsonb_build_object(
      'fecha', r.fecha,
      'nombre_apellidos', btrim(coalesce(r.nombre, '') || ' ' || coalesce(r.apellido, '')),
      'cedula', r.cedula,
      'cargo', r.area,
      'genero', r.genero,
      'formador', r.formador),
    'calificacion_final', jsonb_build_object(
      'nivel', r.promedio,
      'proceso', r.proceso,
      'lider_prueba', r.lider_prueba,
      'aprobo', case r.resultado when 'Aprobado' then 'Sí' when 'Reprobado' then 'No' end,
      'resultado', r.resultado,
      'suma_niveles', r.niveles->'suma',
      'cantidad_niveles', r.niveles->'cantidad'),
    'pruebas', jsonb_build_object(
      'pin_board', jsonb_build_object(
        't1_destreza', r.pin_board_destreza_t1, 't1_calidad', r.pin_board_calidad_t1,
        't2_destreza', r.pin_board_destreza_t2, 't2_calidad', r.pin_board_calidad_t2,
        'mejor_tiempo', n->'pin_board'->'tiempo_segundos'),
      'destreza_fina', jsonb_build_object(
        't1_destreza', r.destreza_fina_destreza_t1, 't1_calidad', r.destreza_fina_calidad_t1,
        't2_destreza', r.destreza_fina_destreza_t2, 't2_calidad', r.destreza_fina_calidad_t2,
        'mejor_tiempo', n->'destreza_fina'->'tiempo_segundos'),
      'speed_stack', jsonb_build_object(
        't1_destreza', r.speed_stack_destreza_t1, 't1_calidad', r.speed_stack_calidad_t1,
        't2_destreza', r.speed_stack_destreza_t2, 't2_calidad', r.speed_stack_calidad_t2,
        'mejor_tiempo', n->'speed_stack'->'tiempo_segundos'),
      'concentracion_conteo', jsonb_build_object(
        't1_destreza', r.concentracion_conteo_destreza_t1,
        't1_calidad', r.concentracion_conteo_calidad_t1,
        'mejor_tiempo', n->'concentracion_conteo'->'tiempo_segundos'),
      'huester', jsonb_build_object(
        't1_destreza', r.habilidad_motora_gruesa_destreza_t1,
        't1_calidad', r.habilidad_motora_gruesa_calidad_t1,
        'tiempo', n->'habilidad_motora_gruesa'->'tiempo_segundos'),
      'prueba_adicional', jsonb_build_object(
        'prueba', r.prueba_campo_tipo,
        't1_destreza', r.prueba_campo_destreza_t1,
        't1_calidad', r.prueba_campo_calidad_t1)),
    'fit_brain', jsonb_build_object(
      't1_velocidad', r.fit_brain_velocidad_t1, 't2_velocidad', r.fit_brain_velocidad_t2,
      't1_acierto', r.fit_brain_porcentaje_acierto_t1, 't2_acierto', r.fit_brain_porcentaje_acierto_t2),
    'operaciones', jsonb_build_object(
      'suma', r.suma, 'resta', r.resta,
      'multiplicacion', r.multiplicacion, 'division', r.division),
    'competencias', jsonb_build_object('filas', filas, 'total', totales),
    'destreza_y_calidad', jsonb_build_object(
      'pin_board', n->'pin_board'->'nivel',
      'destreza_fina', n->'destreza_fina'->'nivel',
      'speed_stack', n->'speed_stack'->'nivel',
      'concentracion_conteo', n->'concentracion_conteo'->'nivel',
      'fit_brain', n->'fit_brain'->'nivel',
      'habilidad_motora_gruesa', n->'habilidad_motora_gruesa'->'nivel',
      'prueba_campo', n->'prueba_campo'->'nivel'),
    'actitud', jsonb_build_object(
      'pin_board', n->'pin_board'->'nivel_actitud',
      'destreza_fina', n->'destreza_fina'->'nivel_actitud',
      'speed_stack', n->'speed_stack'->'nivel_actitud',
      'concentracion_conteo', n->'concentracion_conteo'->'nivel_actitud',
      'fit_brain', n->'fit_brain'->'nivel_actitud',
      'habilidad_motora_gruesa', n->'habilidad_motora_gruesa'->'nivel_actitud',
      'prueba_campo', n->'prueba_campo'->'nivel_actitud')
  );
end;
$$;

revoke all on function public.app_resultado_pdf(text, text, uuid) from public;
grant execute on function public.app_resultado_pdf(text, text, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
