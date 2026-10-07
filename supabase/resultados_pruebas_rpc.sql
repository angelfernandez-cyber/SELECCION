-- ══════════════════════════════════════════════════════════════════════════════
--  SQL para Supabase: Funciones RPC de Resultados de Pruebas
--  Ejecutar en: Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- ─── 1. Listar resultados ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_listar_resultados(
  p_actor_correo    text,
  p_actor_contrasena text
)
RETURNS SETOF resultados_pruebas
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_actor usuarios%ROWTYPE;
BEGIN
  -- Autenticar actor
  SELECT * INTO v_actor
    FROM usuarios
   WHERE correo = p_actor_correo
     AND contrasena = crypt(p_actor_contrasena, contrasena)
     AND activo = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Acceso denegado.';
  END IF;

  -- Sólo admin o con permiso ver_datos
  IF NOT (v_actor.admin OR (v_actor.permisos->>'ver_datos')::boolean IS TRUE
                         OR (v_actor.permisos->>'registrar_datos')::boolean IS TRUE) THEN
    RAISE EXCEPTION 'Sin permiso para ver datos.';
  END IF;

  RETURN QUERY SELECT * FROM resultados_pruebas ORDER BY creado_en DESC;
END;
$$;

-- ─── 2. Guardar (insertar o actualizar) un resultado ─────────────────────────
CREATE OR REPLACE FUNCTION app_guardar_resultado(
  p_actor_correo    text,
  p_actor_contrasena text,
  p_id              uuid            DEFAULT NULL,
  p_fecha           date            DEFAULT CURRENT_DATE,
  p_nombre          text            DEFAULT NULL,
  p_apellido        text            DEFAULT NULL,
  p_cedula          text            DEFAULT NULL,
  p_area            text            DEFAULT NULL,
  p_formador        text            DEFAULT NULL,
  p_proceso         text            DEFAULT NULL,
  p_lider_prueba    text            DEFAULT NULL,
  -- Pin Board
  p_pin_board_destreza_t1    numeric DEFAULT NULL,
  p_pin_board_destreza_t2    numeric DEFAULT NULL,
  p_pin_board_calidad_t1     text    DEFAULT NULL,
  p_pin_board_calidad_t2     text    DEFAULT NULL,
  -- Destreza Fina
  p_destreza_fina_destreza_t1 numeric DEFAULT NULL,
  p_destreza_fina_destreza_t2 numeric DEFAULT NULL,
  p_destreza_fina_calidad_t1  text    DEFAULT NULL,
  p_destreza_fina_calidad_t2  text    DEFAULT NULL,
  -- Speed Stack
  p_speed_stack_destreza_t1  numeric DEFAULT NULL,
  p_speed_stack_destreza_t2  numeric DEFAULT NULL,
  p_speed_stack_calidad_t1   text    DEFAULT NULL,
  p_speed_stack_calidad_t2   text    DEFAULT NULL,
  -- Fit Brain
  p_fit_brain_velocidad_t1            numeric DEFAULT NULL,
  p_fit_brain_velocidad_t2            numeric DEFAULT NULL,
  p_fit_brain_porcentaje_acierto_t1   numeric DEFAULT NULL,
  p_fit_brain_porcentaje_acierto_t2   numeric DEFAULT NULL,
  -- Habilidad Motora Gruesa
  p_habilidad_motora_gruesa_destreza_t1 numeric DEFAULT NULL,
  p_habilidad_motora_gruesa_calidad_t1  text    DEFAULT NULL,
  -- Prueba de Campo
  p_prueba_campo_destreza_t1  numeric DEFAULT NULL,
  p_prueba_campo_calidad_t1   text    DEFAULT NULL,
  -- Concentración y Conteo
  p_concentracion_conteo_destreza_t1  numeric DEFAULT NULL,
  p_concentracion_conteo_calidad_t1   text    DEFAULT NULL,
  -- Operaciones
  p_suma           numeric DEFAULT NULL,
  p_resta          numeric DEFAULT NULL,
  p_multiplicacion numeric DEFAULT NULL,
  p_division       numeric DEFAULT NULL,
  p_competencias   jsonb   DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_actor usuarios%ROWTYPE;
BEGIN
  -- Autenticar actor
  SELECT * INTO v_actor
    FROM usuarios
   WHERE correo = p_actor_correo
     AND contrasena = crypt(p_actor_contrasena, contrasena)
     AND activo = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Acceso denegado.';
  END IF;

  -- Permiso
  IF NOT (v_actor.admin OR (v_actor.permisos->>'registrar_datos')::boolean IS TRUE
                         OR (v_actor.permisos->>'editar_datos')::boolean IS TRUE) THEN
    RAISE EXCEPTION 'Sin permiso para registrar datos.';
  END IF;

  IF p_id IS NULL THEN
    -- INSERT
    INSERT INTO resultados_pruebas (
      fecha, nombre, apellido, cedula, area, formador, proceso, lider_prueba,
      pin_board_destreza_t1, pin_board_destreza_t2,
      pin_board_calidad_t1,  pin_board_calidad_t2,
      destreza_fina_destreza_t1, destreza_fina_destreza_t2,
      destreza_fina_calidad_t1,  destreza_fina_calidad_t2,
      speed_stack_destreza_t1, speed_stack_destreza_t2,
      speed_stack_calidad_t1,  speed_stack_calidad_t2,
      fit_brain_velocidad_t1, fit_brain_velocidad_t2,
      fit_brain_porcentaje_acierto_t1, fit_brain_porcentaje_acierto_t2,
      habilidad_motora_gruesa_destreza_t1, habilidad_motora_gruesa_calidad_t1,
      prueba_campo_destreza_t1, prueba_campo_calidad_t1,
      concentracion_conteo_destreza_t1, concentracion_conteo_calidad_t1,
      suma, resta, multiplicacion, division,
      competencias,
      registrado_por
    ) VALUES (
      p_fecha, p_nombre, p_apellido, p_cedula, p_area, p_formador, p_proceso, p_lider_prueba,
      p_pin_board_destreza_t1, p_pin_board_destreza_t2,
      p_pin_board_calidad_t1,  p_pin_board_calidad_t2,
      p_destreza_fina_destreza_t1, p_destreza_fina_destreza_t2,
      p_destreza_fina_calidad_t1,  p_destreza_fina_calidad_t2,
      p_speed_stack_destreza_t1, p_speed_stack_destreza_t2,
      p_speed_stack_calidad_t1,  p_speed_stack_calidad_t2,
      p_fit_brain_velocidad_t1, p_fit_brain_velocidad_t2,
      p_fit_brain_porcentaje_acierto_t1, p_fit_brain_porcentaje_acierto_t2,
      p_habilidad_motora_gruesa_destreza_t1, p_habilidad_motora_gruesa_calidad_t1,
      p_prueba_campo_destreza_t1, p_prueba_campo_calidad_t1,
      p_concentracion_conteo_destreza_t1, p_concentracion_conteo_calidad_t1,
      p_suma, p_resta, p_multiplicacion, p_division,
      coalesce(p_competencias, '{}'::jsonb),
      v_actor.id
    );
  ELSE
    -- UPDATE
    UPDATE resultados_pruebas SET
      fecha = p_fecha, nombre = p_nombre, apellido = p_apellido,
      cedula = p_cedula, area = p_area, formador = p_formador,
      proceso = p_proceso, lider_prueba = p_lider_prueba,
      pin_board_destreza_t1 = p_pin_board_destreza_t1,
      pin_board_destreza_t2 = p_pin_board_destreza_t2,
      pin_board_calidad_t1  = p_pin_board_calidad_t1,
      pin_board_calidad_t2  = p_pin_board_calidad_t2,
      destreza_fina_destreza_t1 = p_destreza_fina_destreza_t1,
      destreza_fina_destreza_t2 = p_destreza_fina_destreza_t2,
      destreza_fina_calidad_t1  = p_destreza_fina_calidad_t1,
      destreza_fina_calidad_t2  = p_destreza_fina_calidad_t2,
      speed_stack_destreza_t1 = p_speed_stack_destreza_t1,
      speed_stack_destreza_t2 = p_speed_stack_destreza_t2,
      speed_stack_calidad_t1  = p_speed_stack_calidad_t1,
      speed_stack_calidad_t2  = p_speed_stack_calidad_t2,
      fit_brain_velocidad_t1 = p_fit_brain_velocidad_t1,
      fit_brain_velocidad_t2 = p_fit_brain_velocidad_t2,
      fit_brain_porcentaje_acierto_t1 = p_fit_brain_porcentaje_acierto_t1,
      fit_brain_porcentaje_acierto_t2 = p_fit_brain_porcentaje_acierto_t2,
      habilidad_motora_gruesa_destreza_t1 = p_habilidad_motora_gruesa_destreza_t1,
      habilidad_motora_gruesa_calidad_t1  = p_habilidad_motora_gruesa_calidad_t1,
      prueba_campo_destreza_t1 = p_prueba_campo_destreza_t1,
      prueba_campo_calidad_t1  = p_prueba_campo_calidad_t1,
      concentracion_conteo_destreza_t1 = p_concentracion_conteo_destreza_t1,
      concentracion_conteo_calidad_t1  = p_concentracion_conteo_calidad_t1,
      suma = p_suma, resta = p_resta,
      multiplicacion = p_multiplicacion, division = p_division,
      competencias = coalesce(p_competencias, competencias, '{}'::jsonb)
    WHERE id = p_id;
  END IF;
END;
$$;

-- ─── Asegurar tipo TEXT en columnas de calidad y columna competencias ─────────
DO $$
BEGIN
  ALTER TABLE resultados_pruebas ADD COLUMN IF NOT EXISTS competencias jsonb DEFAULT '{}'::jsonb;
  ALTER TABLE resultados_pruebas 
    ALTER COLUMN pin_board_calidad_t1 TYPE text USING pin_board_calidad_t1::text,
    ALTER COLUMN pin_board_calidad_t2 TYPE text USING pin_board_calidad_t2::text,
    ALTER COLUMN destreza_fina_calidad_t1 TYPE text USING destreza_fina_calidad_t1::text,
    ALTER COLUMN destreza_fina_calidad_t2 TYPE text USING destreza_fina_calidad_t2::text,
    ALTER COLUMN speed_stack_calidad_t1 TYPE text USING speed_stack_calidad_t1::text,
    ALTER COLUMN speed_stack_calidad_t2 TYPE text USING speed_stack_calidad_t2::text,
    ALTER COLUMN habilidad_motora_gruesa_calidad_t1 TYPE text USING habilidad_motora_gruesa_calidad_t1::text,
    ALTER COLUMN prueba_campo_calidad_t1 TYPE text USING prueba_campo_calidad_t1::text,
    ALTER COLUMN concentracion_conteo_calidad_t1 TYPE text USING concentracion_conteo_calidad_t1::text;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- ─── Otorgar permisos de ejecución a anon ─────────────────────────────────────
GRANT EXECUTE ON FUNCTION app_listar_resultados(text, text) TO anon;
GRANT EXECUTE ON FUNCTION app_guardar_resultado TO anon;
