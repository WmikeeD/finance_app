# Configuración del Entorno de Desarrollo

## Requisitos Previos

- Flutter SDK >= 3.6.0
- Dart SDK >= 3.6.0

## Configuración Inicial

### 1. Variables de Entorno

Este proyecto utiliza variables de entorno para proteger credenciales sensibles.

**Pasos:**

1. Copia el archivo de plantilla:
   ```bash
   cp .env.example .env
   ```

2. Edita el archivo `.env` y completa tus credenciales de Supabase:
   ```env
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu_anon_key_aqui
   ```

3. **IMPORTANTE:** El archivo `.env` está en `.gitignore` y **NUNCA** debe ser commiteado a Git.

### 2. Instalación de Dependencias

```bash
flutter pub get
```

### 3. Generación de Código (Drift ORM)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Ejecutar la Aplicación

```bash
flutter run
```

## Seguridad

- ✅ Las credenciales de Supabase se cargan desde `.env`
- ✅ El archivo `.env` está excluido de Git
- ✅ Se incluye `.env.example` como plantilla pública
- ✅ El código lanza excepción clara si faltan variables de entorno

## Solución de Problemas

### Error: "Variable de entorno SUPABASE_URL no encontrada"

**Causa:** No existe el archivo `.env` o está mal configurado.

**Solución:**
1. Verifica que existe el archivo `.env` en la raíz del proyecto
2. Confirma que tiene las variables `SUPABASE_URL` y `SUPABASE_ANON_KEY`
3. Reinicia la aplicación con `flutter run`

### Error al compilar: "dotenv.env not found"

**Causa:** El archivo `.env` no está declarado en `assets`.

**Solución:** Verifica que `pubspec.yaml` contiene:
```yaml
flutter:
  assets:
    - .env
```
