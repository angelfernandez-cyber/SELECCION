# La Planicie

Aplicacion Flutter enfocada en tres modulos: usuarios, datos y respaldo/eliminacion.

## Configuracion de Supabase

1. Abre Supabase > SQL Editor y ejecuta `supabase/app_setup.sql`.
2. La migracion usa `public.usuarios`, agrega permisos y crea `public.registros`.
3. Ejecuta Flutter con el Project URL y la clave publica anon/publishable:

```powershell
flutter run --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

El proyecto compartido tiene los valores actuales como configuracion predeterminada. No uses una clave service_role en Flutter. La tabla recibida guarda contrasenas directamente; migra las cuentas a Supabase Auth antes de usar el sistema en produccion.

## Modulos

- Usuarios: crear, activar o desactivar, cambiar contrasena, asignar permisos y eliminar cuentas no administrativas.
- Datos: consultar, registrar y editar registros con titulo y descripcion.
- Respaldo: guardar un JSON local antes de confirmar la eliminacion de registros en Supabase.