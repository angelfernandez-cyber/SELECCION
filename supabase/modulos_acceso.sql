-- ══════════════════════════════════════════════════════════════════════════
--  SELECCIOM · Acceso por módulos
--  Nuevo permiso 'exportar_pdf' (módulo Exportación e impresión PDF).
--  Permite listar resultados y generar el PDF a quien tenga ese permiso,
--  aunque no tenga ver_datos / registrar_datos.
--  Se puede ejecutar varias veces.
-- ══════════════════════════════════════════════════════════════════════════
do $$
declare f record; def text;
begin
  for f in
    select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname in ('app_listar_resultados_pag', 'app_resultado_pdf')
  loop
    def := pg_get_functiondef(f.oid);
    if position('exportar_pdf' in def) = 0 then
      def := regexp_replace(
        def,
        '(registrar_datos''\)::boolean, false\))(\s+then\s+raise exception ''No tienes permiso para ver datos'')',
        '\1' || E'\n     and not coalesce((v.permisos->>''exportar_pdf'')::boolean, false)' || '\2');
      execute def;
    end if;
  end loop;
end $$;

-- Los usuarios que ya tenían ver_datos quedan con acceso al módulo PDF.
update public.usuarios
   set permisos = permisos || '{"exportar_pdf": true}'::jsonb
 where not (permisos ? 'exportar_pdf')
   and coalesce((permisos->>'ver_datos')::boolean, false);

notify pgrst, 'reload schema';
