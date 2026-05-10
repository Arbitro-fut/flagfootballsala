# GitHub Pages - Confirmación de árbitros

Esta carpeta contiene la página centralizada para que los árbitros inicien sesión con correo y contraseña, confirmen participación y capturen hasta tres bloqueos personales.

## Publicación

1. Copia la carpeta `github-pages/referee-availability` a tu repositorio de GitHub Pages.
2. Verifica `config.js`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. En GitHub activa **Settings > Pages**.
4. Publica desde la rama que uses para Pages.
5. La URL final será parecida a:

```text
https://TU_USUARIO.github.io/TU_REPOSITORIO/referee-availability/
```

Esa URL es la que debes capturar en la app al crear la solicitud de disponibilidad.

## Seguridad

- No usa `service_role`.
- No usa token manual por árbitro.
- El árbitro inicia sesión con **Supabase Auth** usando correo y contraseña.
- La RPC identifica al árbitro con `auth.uid()`.
- La cuenta Auth debe estar vinculada al árbitro mediante `referees.auth_user_id` o mediante `referees.id = auth.uid()`.
- Las respuestas solo se aceptan si el árbitro está incluido en `availability_request_recipients` para esa solicitud.

## Flujo

1. La app crea una fila en `availability_requests` con la fecha de jornada.
2. Supabase calcula `registration_closes_at = schedule_start_at - 72 horas`.
3. El árbitro entra a la página central.
4. Inicia sesión con correo y contraseña.
5. Confirma participación.
6. Captura hasta tres bloqueos personales.
7. Supabase guarda:
   - respuesta formal en `availability_request_responses`
   - bloqueos operativos en `referee_unavailability`
8. El generador de roles sigue usando `referee_unavailability` como ya lo hace actualmente.

## Requisito de vinculación

Para que un árbitro pueda contestar, debe existir una relación entre su cuenta Auth y su registro en `referees`.

La implementación soporta dos formas:

```text
referees.id = auth.users.id
```

o:

```text
referees.auth_user_id = auth.users.id
```

El SQL incluido intenta completar `referees.auth_user_id` automáticamente a partir de perfiles activos en `profiles`.
