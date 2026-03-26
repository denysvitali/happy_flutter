// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Happy';

  @override
  String get appSubtitle => 'Cliente móvil para Claude Code & Codex';

  @override
  String get appVersion => 'Versión';

  @override
  String get appLoading => 'Cargando...';

  @override
  String get appRetry => 'Reintentar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSaveAs => 'Guardar como';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonReset => 'Restablecer';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Éxito';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get commonLogout => 'Cerrar sesión';

  @override
  String get commonDiscard => 'Descartar';

  @override
  String get commonOptional => 'opcional';

  @override
  String get commonScanning => 'Escaneando...';

  @override
  String get commonUrlPlaceholder => 'https://ejemplo.com';

  @override
  String get commonHome => 'Inicio';

  @override
  String get commonMessage => 'Mensaje';

  @override
  String get commonFiles => 'Archivos';

  @override
  String get commonFileViewer => 'Visor de archivos';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonDeleteConfirmTitle => 'Confirmar eliminación';

  @override
  String get commonDeleteConfirmMessage =>
      '¿Estás seguro de que quieres eliminar esto?';

  @override
  String get tabsInbox => 'Bandeja';

  @override
  String get tabsSessions => 'Terminales';

  @override
  String get tabsSettings => 'Configuración';

  @override
  String get inboxEmptyTitle => 'Bandeja vacía';

  @override
  String get inboxEmptyDescription =>
      'Conecta con amigos para comenzar a compartir sesiones';

  @override
  String get inboxUpdates => 'Actualizaciones';

  @override
  String statusConnected(String time) {
    return 'Conectado';
  }

  @override
  String get statusConnecting => 'Conectando';

  @override
  String get statusDisconnected => 'Desconectado';

  @override
  String get statusError => 'Error';

  @override
  String get statusOnline => 'En línea';

  @override
  String get statusOffline => 'Fuera de línea';

  @override
  String get statusActiveNow => 'Activo ahora';

  @override
  String get statusUnknown => 'Desconocido';

  @override
  String get statusPermissionRequired => 'Permiso requerido';

  @override
  String statusLastSeen(Object time) {
    return 'Última vez $time';
  }

  @override
  String get timeJustNow => 'justo ahora';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'Autenticar';

  @override
  String get authAccessDenied => 'Acceso denegado';

  @override
  String get authAuthenticationFailed => 'Autenticación fallida';

  @override
  String get authEnterSecretKey => 'Por favor ingresa una clave secreta';

  @override
  String get authInvalidSecretKey =>
      'Clave secreta inválida. Por favor verifica e intenta de nuevo.';

  @override
  String get authRestoreAccount => 'Restaurar cuenta';

  @override
  String get authEnterUrlManually => 'Ingresar URL manualmente';

  @override
  String get authPasteAuthUrl => 'Pega la URL de autenticación de tu terminal';

  @override
  String get authAuthenticateTerminal => 'Autenticar terminal';

  @override
  String get authAuthenticateWithUrlPaste =>
      'Autenticar terminal con pegar URL';

  @override
  String get authCameraPermissionsRequired =>
      'Se requieren permisos de cámara para escanear códigos QR';

  @override
  String get authExchangingTokens => 'Intercambiando tokens...';

  @override
  String get authClaudeAuthSuccess => 'Conectado exitosamente a Claude';

  @override
  String get welcomeTitle => 'Cliente móvil de Codex y Claude Code';

  @override
  String get welcomeSubtitle =>
      'Cifrado de extremo a extremo y tu cuenta se almacena solo en tu dispositivo.';

  @override
  String get welcomeCreateAccount => 'Crear cuenta';

  @override
  String get welcomeLinkOrRestoreAccount => 'Vincular o restaurar cuenta';

  @override
  String get welcomeLoginWithMobileApp =>
      'Iniciar sesión con la aplicación móvil';

  @override
  String get sessionTitle => 'Sesiones';

  @override
  String get sessionNewSession => 'Nueva sesión';

  @override
  String get sessionStartNewToGetStarted =>
      'Inicia una nueva sesión para comenzar';

  @override
  String get sessionNoSessionsYet => 'Aún no hay sesiones';

  @override
  String get sessionActiveSessions => 'Activo';

  @override
  String get sessionHistory => 'Historial';

  @override
  String get sessionMachine => 'Máquina';

  @override
  String get sessionSelectMachine => 'Seleccionar una máquina';

  @override
  String get sessionPath => 'Ruta';

  @override
  String get sessionPathHint => 'Ingresa la ruta';

  @override
  String get sessionInitialMessage => 'Initial message';

  @override
  String get sessionInitialMessageHint => 'What would you like to work on?';

  @override
  String get sessionInputPlaceholder => 'Escribe un mensaje ...';

  @override
  String get sessionStartSession => 'Iniciar sesión';

  @override
  String get sessionStarting => 'Iniciando sesión...';

  @override
  String get sessionStarted => 'Sesión iniciada';

  @override
  String get sessionStartedMessage =>
      'La sesión ha sido iniciada exitosamente.';

  @override
  String get sessionFailedToStart =>
      'Error al iniciar la sesión. Asegúrate de que el daemon esté ejecutándose en la máquina objetivo.';

  @override
  String get sessionTimeout =>
      'El inicio de la sesión expiró. La máquina puede estar lenta o el daemon no está respondiendo.';

  @override
  String get sessionNotConnectedToServer =>
      'No conectado al servidor. Verifica tu conexión a internet.';

  @override
  String get sessionNoMachineSelected =>
      'Por favor selecciona una máquina para iniciar la sesión';

  @override
  String get sessionNoPathSelected =>
      'Por favor selecciona un directorio para iniciar la sesión';

  @override
  String get sessionTypeTitle => 'Tipo de sesión';

  @override
  String get sessionTypeSimple => 'Simple';

  @override
  String get sessionTypeWorktree => 'Worktree';

  @override
  String get sessionTypeComingSoon => 'Próximamente';

  @override
  String newSessionTitle(String directory) {
    return 'Iniciar nueva sesión';
  }

  @override
  String get newSessionNoMachinesFound =>
      'No se encontraron máquinas. Primero inicia una sesión de Happy en tu computadora.';

  @override
  String get newSessionAllMachinesOffline =>
      'Todas las máquinas parecen estar fuera de línea';

  @override
  String get newSessionMachineDetails => 'Ver detalles de la máquina →';

  @override
  String get newSessionDirectoryDoesNotExist => 'Directorio no encontrado';

  @override
  String newSessionCreateDirectoryConfirm(Object directory) {
    return 'El directorio $directory no existe. ¿Deseas crearlo?';
  }

  @override
  String get newSessionSessionSpawningFailed =>
      'Error al crear la sesión - no se devolvió ningún ID de sesión.';

  @override
  String sessionHistoryTitle(int count) {
    return 'Historial de sesiones';
  }

  @override
  String get sessionHistoryEmpty => 'No se encontraron sesiones';

  @override
  String get sessionHistoryToday => 'Hoy';

  @override
  String get sessionHistoryYesterday => 'Ayer';

  @override
  String sessionHistoryDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryViewAll => 'Ver todas las sesiones';

  @override
  String sessionInfoTitle(String currentVersion, String requiredVersion) {
    return 'Información de sesión';
  }

  @override
  String get sessionInfoHappySessionId => 'ID de sesión de Happy';

  @override
  String get sessionInfoClaudeCodeSessionId => 'ID de sesión de Claude Code';

  @override
  String get sessionInfoAiProvider => 'Proveedor de IA';

  @override
  String get sessionInfoConnectionStatus => 'Estado de conexión';

  @override
  String get sessionInfoCreated => 'Creado';

  @override
  String get sessionInfoLastUpdated => 'Última actualización';

  @override
  String get sessionInfoSequence => 'Secuencia';

  @override
  String get sessionInfoMetadata => 'Metadatos';

  @override
  String get sessionInfoHost => 'Host';

  @override
  String get sessionInfoPath => 'Ruta';

  @override
  String get sessionInfoOperatingSystem => 'Sistema operativo';

  @override
  String get sessionInfoProcessId => 'ID de proceso';

  @override
  String get sessionInfoCliVersion => 'Versión de CLI';

  @override
  String get sessionInfoAgentState => 'Estado del agente';

  @override
  String get sessionInfoControlledByUser => 'Controlado por el usuario';

  @override
  String get sessionInfoPendingRequests => 'Solicitudes pendientes';

  @override
  String get sessionInfoActivity => 'Actividad';

  @override
  String get sessionInfoThinking => 'Pensando';

  @override
  String get sessionInfoThinkingSince => 'Pensando desde';

  @override
  String get sessionInfoCliVersionOutdated => 'Actualización de CLI requerida';

  @override
  String sessionInfoCliVersionOutdatedMessage(
    Object currentVersion,
    Object requiredVersion,
  ) {
    return 'Versión $currentVersion instalada. Actualiza a $requiredVersion o posterior';
  }

  @override
  String get sessionInfoUpdateCliInstructions =>
      'Por favor ejecuta npm install -g happy-coder@latest';

  @override
  String get sessionInfoQuickActions => 'Acciones rápidas';

  @override
  String get sessionInfoViewMachine => 'Ver máquina';

  @override
  String get sessionInfoViewMachineSubtitle =>
      'Ver detalles de la máquina y sesiones';

  @override
  String get sessionInfoKillSession => 'Terminar sesión';

  @override
  String get sessionInfoKillSessionConfirm =>
      '¿Estás seguro de que deseas terminar esta sesión?';

  @override
  String get sessionInfoKillSessionSubtitle =>
      'Terminar la sesión inmediatamente';

  @override
  String get sessionInfoArchiveSession => 'Archivar sesión';

  @override
  String get sessionInfoArchiveSessionConfirm =>
      '¿Estás seguro de que deseas archivar esta sesión?';

  @override
  String get sessionInfoArchiveSessionSubtitle =>
      'Archivar esta sesión y detenerla';

  @override
  String get sessionInfoDeleteSession => 'Eliminar sesión';

  @override
  String get sessionInfoDeleteSessionSubtitle =>
      'Eliminar esta sesión permanentemente';

  @override
  String get sessionInfoDeleteSessionConfirm =>
      '¿Eliminar sesión permanentemente?';

  @override
  String get sessionInfoDeleteSessionWarning =>
      'Esta acción no se puede deshacer. Todos los mensajes y datos asociados con esta sesión se eliminarán permanentemente.';

  @override
  String get sessionInfoCopySessionId => 'Copiar ID de sesión';

  @override
  String get sessionInfoCopyMetadata => 'Copiar metadatos';

  @override
  String get sessionInfoSessionIdCopied =>
      'ID de sesión copiado al portapapeles';

  @override
  String get sessionInfoMetadataCopied => 'Metadatos copiados al portapapeles';

  @override
  String get sessionInfoCopyFailed => 'Error al copiar al portapapeles';

  @override
  String get sessionInfoHappyHome => 'Happy Home';

  @override
  String get sessionInfoFailedToKillSession => 'Error al terminar la sesión';

  @override
  String get sessionInfoFailedToArchiveSession => 'Error al archivar la sesión';

  @override
  String get sessionInfoFailedToDeleteSession => 'Error al eliminar la sesión';

  @override
  String get sessionInfoSessionDeleted => 'Sesión eliminada exitosamente';

  @override
  String machineTitle(int count) {
    return 'Máquina';
  }

  @override
  String get machineLaunchNewSessionInDirectory =>
      'Iniciar nueva sesión en directorio';

  @override
  String get machineOfflineUnableToSpawn =>
      'Lanzador deshabilitado mientras la máquina está fuera de línea';

  @override
  String get machineOfflineHelp =>
      '• Asegúrate de que tu computadora esté en línea\n• Ejecuta `happy daemon status` para diagnosticar\n• ¿Estás ejecutando la última versión del CLI? Actualiza con `npm install -g happy-coder@latest`';

  @override
  String get machineDaemon => 'Daemon';

  @override
  String get machineStatus => 'Estado';

  @override
  String get machineStopDaemon => 'Detener daemon';

  @override
  String get machineLastKnownPid => 'Último PID conocido';

  @override
  String get machineLastKnownHttpPort => 'Último puerto HTTP conocido';

  @override
  String get machineStartedAt => 'Iniciado a las';

  @override
  String get machineCliVersion => 'Versión de CLI';

  @override
  String get machineDaemonStateVersion => 'Versión del estado del daemon';

  @override
  String machineActiveSessions(Object count) {
    return 'Sesiones activas ($count)';
  }

  @override
  String get machineMachineGroup => 'Máquina';

  @override
  String get machineHost => 'Host';

  @override
  String get machineMachineId => 'ID de máquina';

  @override
  String get machineUsername => 'Nombre de usuario';

  @override
  String get machineHomeDirectory => 'Directorio de inicio';

  @override
  String get machinePlatform => 'Plataforma';

  @override
  String get machineArchitecture => 'Arquitectura';

  @override
  String get machineLastSeen => 'Última vez visto';

  @override
  String get machineNever => 'Nunca';

  @override
  String get machineMetadataVersion => 'Versión de metadatos';

  @override
  String get machineUntitledSession => 'Sesión sin título';

  @override
  String get machineBack => 'Atrás';

  @override
  String get machineShowLess => 'Mostrar menos';

  @override
  String machineShowAll(Object count) {
    return 'Mostrar todo ($count rutas)';
  }

  @override
  String get machineEnterCustomPath => 'Ingresar ruta personalizada';

  @override
  String get machineOfflineUnableToSpawnNew =>
      'No se puede crear nueva sesión, fuera de línea';

  @override
  String chatTitle(String toolName) {
    return 'Chat';
  }

  @override
  String get chatStartConversation => 'Iniciar una conversación';

  @override
  String get chatSendMessageToBegin => 'Envía un mensaje para comenzar';

  @override
  String get chatSessionSettings => 'Configuración de sesión';

  @override
  String get chatDeleteSession => 'Eliminar sesión';

  @override
  String get chatDeleteSessionConfirm =>
      '¿Estás seguro de que deseas eliminar esta sesión?';

  @override
  String get chatFailedToSend => 'Error al enviar mensaje';

  @override
  String get chatThinking => 'Claude está pensando...';

  @override
  String chatToolRunning(Object toolName) {
    return 'Ejecutando: $toolName';
  }

  @override
  String settingsTitle(String login) {
    return 'Configuración';
  }

  @override
  String get settingsConnectedAccounts => 'Cuentas conectadas';

  @override
  String get settingsConnectAccount => 'Conectar cuenta';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsMachines => 'Máquinas';

  @override
  String get settingsFeatures => 'Características';

  @override
  String get settingsSocial => 'Social';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsAccountSubtitle => 'Administrar los detalles de tu cuenta';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAppearanceSubtitle =>
      'Personalizar cómo se ve la aplicación';

  @override
  String get settingsVoiceAssistant => 'Asistente de voz';

  @override
  String get settingsVoiceAssistantSubtitle =>
      'Configurar preferencias de interacción de voz';

  @override
  String get settingsFeaturesTitle => 'Características';

  @override
  String get settingsFeaturesSubtitle =>
      'Habilitar o deshabilitar características de la aplicación';

  @override
  String get settingsDeveloper => 'Desarrollador';

  @override
  String get settingsDeveloperTools => 'Herramientas de desarrollador';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsAboutFooter =>
      'Happy Coder es un cliente móvil de Codex y Claude Code. Está completamente cifrado de extremo a extremo y tu cuenta se almacena solo en tu dispositivo. No está afiliado con Anthropic.';

  @override
  String get settingsWhatsNew => 'Novedades';

  @override
  String get settingsWhatsNewSubtitle =>
      'Ver las últimas actualizaciones y mejoras';

  @override
  String get settingsReportIssue => 'Reportar un problema';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsTermsOfService => 'Términos de servicio';

  @override
  String get settingsEula => 'EULA';

  @override
  String get settingsSupportUs => 'Apóyanos';

  @override
  String get settingsSupportUsSubtitlePro => '¡Gracias por tu apoyo!';

  @override
  String get settingsSupportUsSubtitle => 'Apoyar el desarrollo del proyecto';

  @override
  String get settingsScanQrCodeToAuthenticate =>
      'Escanea el código QR para autenticarte';

  @override
  String settingsGithubConnected(Object login) {
    return 'Conectado como @$login';
  }

  @override
  String get settingsConnectGithubAccount => 'Conecta tu cuenta de GitHub';

  @override
  String get settingsUsage => 'Uso';

  @override
  String get settingsUsageSubtitle => 'Ver tu uso y costos de API';

  @override
  String get settingsProfiles => 'Perfiles';

  @override
  String get settingsProfilesSubtitle =>
      'Administrar perfiles de variables de entorno para sesiones';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutConfirm =>
      '¿Estás seguro de que deseas cerrar sesión? ¡Asegúrate de haber hecho una copia de seguridad de tu clave secreta!';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSubtitle =>
      'Elige tu idioma preferido para la interfaz de la aplicación';

  @override
  String get settingsLanguageCurrent => 'Idioma actual';

  @override
  String get settingsLanguageAutomatic => 'Automático';

  @override
  String get settingsLanguageAutomaticSubtitle =>
      'Detectar de la configuración del dispositivo';

  @override
  String get settingsLanguageNeedsRestart => 'Idioma cambiado';

  @override
  String get settingsLanguageNeedsRestartMessage =>
      'La aplicación necesita reiniciarse para aplicar el nuevo idioma.';

  @override
  String get settingsLanguageRestartNow => 'Reiniciar ahora';

  @override
  String get settingsLanguageSearchPlaceholder => 'Buscar idiomas...';

  @override
  String get settingsAppearanceTheme => 'Tema';

  @override
  String get settingsAppearanceThemeSubtitle =>
      'Elige tu esquema de colores preferido';

  @override
  String get settingsAppearanceThemeAdaptive => 'Adaptativo';

  @override
  String get settingsAppearanceThemeAdaptiveSubtitle =>
      'Coincidir con la configuración del sistema';

  @override
  String get settingsAppearanceThemeLight => 'Claro';

  @override
  String get settingsAppearanceThemeLightSubtitle => 'Siempre usar tema claro';

  @override
  String get settingsAppearanceThemeDark => 'Oscuro';

  @override
  String get settingsAppearanceThemeDarkSubtitle => 'Siempre usar tema oscuro';

  @override
  String get settingsAppearanceDisplay => 'Pantalla';

  @override
  String get settingsAppearanceDisplaySubtitle =>
      'Controlar diseño y espaciado';

  @override
  String get settingsAppearanceInlineToolCalls =>
      'Llamadas de herramientas en línea';

  @override
  String get settingsAppearanceInlineToolCallsSubtitle =>
      'Mostrar llamadas de herramientas directamente en mensajes de chat';

  @override
  String get settingsAppearanceExpandTodoLists => 'Expandir listas de tareas';

  @override
  String get settingsAppearanceExpandTodoListsSubtitle =>
      'Mostrar todas las tareas en lugar de solo cambios';

  @override
  String get settingsAppearanceShowLineNumbersInDiffs =>
      'Mostrar números de línea en diffs';

  @override
  String get settingsAppearanceShowLineNumbersInDiffsSubtitle =>
      'Mostrar números de línea en diffs de código';

  @override
  String get settingsAppearanceShowLineNumbersInToolViews =>
      'Mostrar números de línea en vistas de herramientas';

  @override
  String get settingsAppearanceShowLineNumbersInToolViewsSubtitle =>
      'Mostrar números de línea en diffs de vistas de herramientas';

  @override
  String get settingsAppearanceWrapLinesInDiffs => 'Ajustar líneas en diffs';

  @override
  String get settingsAppearanceWrapLinesInDiffsSubtitle =>
      'Ajustar líneas largas en lugar de desplazamiento horizontal en vistas de diff';

  @override
  String get settingsAppearanceAlwaysShowContextSize =>
      'Siempre mostrar tamaño de contexto';

  @override
  String get settingsAppearanceAlwaysShowContextSizeSubtitle =>
      'Mostrar uso de contexto incluso cuando no está cerca del límite';

  @override
  String get settingsAppearanceAvatarStyle => 'Estilo de avatar';

  @override
  String get settingsAppearanceAvatarStyleSubtitle =>
      'Elegir apariencia del avatar de sesión';

  @override
  String get settingsAppearanceAvatarStylePixelated => 'Pixelado';

  @override
  String get settingsAppearanceAvatarStyleGradient => 'Gradiente';

  @override
  String get settingsAppearanceAvatarStyleBrutalist => 'Brutalista';

  @override
  String get settingsAppearanceShowFlavorIcons =>
      'Mostrar iconos de proveedores de IA';

  @override
  String get settingsAppearanceShowFlavorIconsSubtitle =>
      'Mostrar iconos de proveedores de IA en avatares de sesión';

  @override
  String get settingsAppearanceCompactSessionView => 'Vista compacta de sesión';

  @override
  String get settingsAppearanceCompactSessionViewSubtitle =>
      'Mostrar sesiones activas en un diseño más compacto';

  @override
  String get settingsFeaturesExperiments => 'Experimentos';

  @override
  String get settingsFeaturesExperimentsSubtitle =>
      'Habilitar características experimentales que aún están en desarrollo. Estas características pueden ser inestables o cambiar sin previo aviso.';

  @override
  String get settingsFeaturesExperimentalFeatures =>
      'Características experimentales';

  @override
  String get settingsFeaturesExperimentalFeaturesEnabled =>
      'Características experimentales habilitadas';

  @override
  String get settingsFeaturesExperimentalFeaturesDisabled =>
      'Usando características estables únicamente';

  @override
  String get settingsFeaturesWebFeatures => 'Características web';

  @override
  String get settingsFeaturesWebFeaturesSubtitle =>
      'Características disponibles solo en la versión web de la aplicación.';

  @override
  String get settingsFeaturesEnterToSend => 'Enter para enviar';

  @override
  String get settingsFeaturesEnterToSendEnabled =>
      'Presiona Enter para enviar (Shift+Enter para nueva línea)';

  @override
  String get settingsFeaturesEnterToSendDisabled =>
      'Enter inserta una nueva línea';

  @override
  String get settingsFeaturesCommandPalette => 'Paleta de comandos';

  @override
  String get settingsFeaturesCommandPaletteEnabled => 'Presiona ⌘K para abrir';

  @override
  String get settingsFeaturesCommandPaletteDisabled =>
      'Acceso rápido a comandos deshabilitado';

  @override
  String get settingsFeaturesMarkdownCopyV2 => 'Copiar Markdown v2';

  @override
  String get settingsFeaturesMarkdownCopyV2Subtitle =>
      'Mantener presionado abre modal de copia';

  @override
  String get settingsFeaturesHideInactiveSessions =>
      'Ocultar sesiones inactivas';

  @override
  String get settingsFeaturesHideInactiveSessionsSubtitle =>
      'Mostrar solo chats activos en tu lista';

  @override
  String get settingsFeaturesEnhancedSessionWizard =>
      'Asistente de sesión mejorado';

  @override
  String get settingsFeaturesEnhancedSessionWizardEnabled =>
      'Lanzador de sesión basado en perfil activo';

  @override
  String get settingsFeaturesEnhancedSessionWizardDisabled =>
      'Usando lanzador de sesión estándar';

  @override
  String get settingsAccountTitle => 'Configuración de cuenta';

  @override
  String get settingsAccountStatus => 'Estado';

  @override
  String get settingsAccountStatusActive => 'Activo';

  @override
  String get settingsAccountStatusNotAuthenticated => 'No autenticado';

  @override
  String get settingsAccountAnonymousId => 'ID anónimo';

  @override
  String get settingsAccountPublicId => 'ID público';

  @override
  String get settingsAccountNotAvailable => 'No disponible';

  @override
  String get settingsAccountLinkNewDevice => 'Vincular nuevo dispositivo';

  @override
  String get settingsAccountLinkNewDeviceSubtitle =>
      'Escanea el código QR para vincular dispositivo';

  @override
  String get settingsAccountProfile => 'Perfil';

  @override
  String get settingsAccountName => 'Nombre';

  @override
  String get settingsAccountGithub => 'GitHub';

  @override
  String get settingsAccountTapToDisconnect => 'Toca para desconectar';

  @override
  String get settingsAccountServer => 'Servidor';

  @override
  String get settingsAccountBackup => 'Respaldo';

  @override
  String get settingsAccountBackupDescription =>
      'Tu clave secreta es la única forma de recuperar tu cuenta. Guárdala en un lugar seguro como un administrador de contraseñas.';

  @override
  String get settingsAccountSecretKey => 'Clave secreta';

  @override
  String get settingsAccountTapToReveal => 'Toca para revelar';

  @override
  String get settingsAccountTapToHide => 'Toca para ocultar';

  @override
  String get settingsAccountSecretKeyLabel =>
      'CLAVE SECRETA (TOCA PARA COPIAR)';

  @override
  String get settingsAccountSecretKeyCopied =>
      'Clave secreta copiada al portapapeles. ¡Guárdala en un lugar seguro!';

  @override
  String get settingsAccountSecretKeyCopyFailed =>
      'Error al copiar la clave secreta';

  @override
  String get settingsAccountPrivacy => 'Privacidad';

  @override
  String get settingsAccountPrivacyDescription =>
      'Ayuda a mejorar la aplicación compartiendo datos de uso anónimos. No se recopila información personal.';

  @override
  String get settingsAccountAnalytics => 'Analítica';

  @override
  String get settingsAccountAnalyticsDisabled => 'No se comparten datos';

  @override
  String get settingsAccountAnalyticsEnabled =>
      'Se comparten datos de uso anónimos';

  @override
  String get settingsAccountDangerZone => 'Zona de peligro';

  @override
  String get settingsAccountLogout => 'Cerrar sesión';

  @override
  String get settingsAccountLogoutSubtitle => 'Salir y borrar datos locales';

  @override
  String get settingsServerTitle => 'Configuración del servidor';

  @override
  String get settingsServerUrl => 'URL del servidor';

  @override
  String get settingsServerUrlLabel => 'Por favor ingresa la URL del servidor';

  @override
  String get settingsServerNotValidHappyServer =>
      'No es un servidor de Happy válido';

  @override
  String get settingsServerChangeServer => 'Cambiar servidor';

  @override
  String get settingsServerContinueWithServer =>
      '¿Continuar con este servidor?';

  @override
  String get settingsServerResetToDefault => 'Restablecer a predeterminado';

  @override
  String get settingsServerResetServerDefault =>
      '¿Restablecer servidor a predeterminado?';

  @override
  String get settingsServerValidating => 'Validando...';

  @override
  String get settingsServerValidatingServer => 'Validando servidor...';

  @override
  String get settingsServerServerReturnedError =>
      'El servidor devolvió un error';

  @override
  String get settingsServerFailedToConnectToServer =>
      'Error al conectar al servidor';

  @override
  String get settingsServerCurrentlyUsingCustomServer =>
      'Usando servidor personalizado actualmente';

  @override
  String get settingsServerCustomServerUrlLabel =>
      'URL del servidor personalizado';

  @override
  String get settingsServerAdvancedFeatureFooter =>
      'Esta es una característica avanzada. Solo cambia el servidor si sabes lo que estás haciendo. Necesitarás cerrar sesión e iniciar sesión nuevamente después de cambiar de servidor.';

  @override
  String get settingsVoiceTitle => 'Asistente de voz';

  @override
  String get settingsVoiceLanguage => 'Idioma';

  @override
  String get settingsVoiceLanguageSubtitle =>
      'Elige tu idioma preferido para las interacciones del asistente de voz. Esta configuración se sincroniza en todos tus dispositivos.';

  @override
  String get settingsVoicePreferredLanguage => 'Idioma preferido';

  @override
  String get settingsVoicePreferredLanguageSubtitle =>
      'Idioma usado para respuestas del asistente de voz';

  @override
  String get settingsVoiceLanguageSearchPlaceholder => 'Buscar idiomas...';

  @override
  String get settingsVoiceLanguageSearchTitle => 'Idiomas';

  @override
  String settingsVoiceLanguageFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count idiomas',
      one: '1 idioma',
    );
    return '$_temp0 disponibles';
  }

  @override
  String get settingsVoiceLanguageAutoDetect => 'Detección automática';

  @override
  String get settingsProfilesTitle => 'Perfiles';

  @override
  String get settingsProfilesNoProfile => 'Sin perfil';

  @override
  String get settingsProfilesNoProfileDescription =>
      'Usar configuración de entorno predeterminada';

  @override
  String get settingsProfilesDefaultModel => 'Modelo predeterminado';

  @override
  String get settingsProfilesAddProfile => 'Agregar perfil';

  @override
  String get settingsProfilesProfileName => 'Nombre del perfil';

  @override
  String get settingsProfilesEnterName => 'Ingresa el nombre del perfil';

  @override
  String get settingsProfilesBaseUrl => 'URL base';

  @override
  String get settingsProfilesAuthToken => 'Token de autenticación';

  @override
  String get settingsProfilesEnterToken => 'Ingresa el token de autenticación';

  @override
  String get settingsProfilesModel => 'Modelo';

  @override
  String get settingsProfilesTmuxSession => 'Sesión de Tmux';

  @override
  String get settingsProfilesEnterTmuxSession =>
      'Ingresa el nombre de la sesión de tmux';

  @override
  String get settingsProfilesTmuxTempDir => 'Directorio temporal de Tmux';

  @override
  String get settingsProfilesEnterTmuxTempDir =>
      'Ingresa la ruta del directorio temporal';

  @override
  String get settingsProfilesTmuxUpdateEnvironment =>
      'Actualizar entorno automáticamente';

  @override
  String get settingsProfilesNameRequired =>
      'El nombre del perfil es requerido';

  @override
  String settingsProfilesDeleteConfirm(String name) {
    return '¿Estás seguro de que deseas eliminar el perfil \"$name\"?';
  }

  @override
  String get settingsProfilesEditProfile => 'Editar perfil';

  @override
  String get settingsProfilesAddProfileTitle => 'Agregar nuevo perfil';

  @override
  String get settingsProfilesDeleteTitle => 'Eliminar perfil';

  @override
  String settingsProfilesDeleteMessage(Object name) {
    return '¿Estás seguro de que deseas eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get settingsProfilesDeleteConfirmAction => 'Eliminar';

  @override
  String get settingsProfilesDeleteCancel => 'Cancelar';

  @override
  String get settingsUsageTitle => 'Uso';

  @override
  String get settingsUsageToday => 'Hoy';

  @override
  String get settingsUsageLast7Days => 'Últimos 7 días';

  @override
  String get settingsUsageLast30Days => 'Últimos 30 días';

  @override
  String get settingsUsageTotalTokens => 'Tokens totales';

  @override
  String get settingsUsageTotalCost => 'Costo total';

  @override
  String get settingsUsageTokens => 'Tokens';

  @override
  String get settingsUsageCost => 'Costo';

  @override
  String get settingsUsageUsageOverTime => 'Uso a lo largo del tiempo';

  @override
  String get settingsUsageByModel => 'Por modelo';

  @override
  String get settingsUsageNoData => 'No hay datos de uso disponibles';

  @override
  String get settingsDeveloperTitle => 'Desarrollador';

  @override
  String settingsDeveloperVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get settingsDeveloperCopyDebugInfo =>
      'Copiar información de depuración';

  @override
  String get settingsDeveloperDebugInfoCopied =>
      'Información de depuración copiada al portapapeles';

  @override
  String get errorsNetworkError => 'Error de red ocurrido';

  @override
  String get errorsServerError => 'Error de servidor ocurrido';

  @override
  String get errorsUnknownError => 'Ocurrió un error desconocido';

  @override
  String get errorsConnectionTimeout => 'Conexión expiró';

  @override
  String get errorsAuthenticationFailed => 'Autenticación fallida';

  @override
  String get errorsPermissionDenied => 'Permiso denegado';

  @override
  String get errorsFileNotFound => 'Archivo no encontrado';

  @override
  String get errorsInvalidFormat => 'Formato inválido';

  @override
  String get errorsOperationFailed => 'Operación fallida';

  @override
  String get errorsTryAgain => 'Por favor intenta de nuevo';

  @override
  String get errorsContactSupport => 'Contacta soporte si el problema persiste';

  @override
  String get errorsSessionNotFound => 'Sesión no encontrada';

  @override
  String get errorsVoiceSessionFailed => 'Error al iniciar sesión de voz';

  @override
  String get errorsVoiceServiceUnavailable =>
      'El servicio de voz está temporalmente no disponible';

  @override
  String get errorsOauthInitializationFailed =>
      'Error al inicializar flujo de OAuth';

  @override
  String get errorsTokenStorageFailed =>
      'Error al almacenar tokens de autenticación';

  @override
  String get errorsOauthStateMismatch =>
      'Validación de seguridad fallida. Por favor intenta de nuevo';

  @override
  String get errorsTokenExchangeFailed =>
      'Error al intercambiar código de autorización';

  @override
  String get errorsOauthAuthorizationDenied => 'Autorización denegada';

  @override
  String get errorsWebViewLoadFailed =>
      'Error al cargar página de autenticación';

  @override
  String get errorsFailedToLoadProfile => 'Error al cargar perfil de usuario';

  @override
  String get errorsUserNotFound => 'Usuario no encontrado';

  @override
  String get errorsSessionDeleted => 'La sesión ha sido eliminada';

  @override
  String get errorsSessionDeletedDescription =>
      'Esta sesión ha sido eliminada permanentemente';

  @override
  String errorsFieldError(String field, String reason) {
    return '$field: $reason';
  }

  @override
  String errorsValidationError(String field, int min, int max) {
    return '$field debe estar entre $min y $max';
  }

  @override
  String errorsRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return 'Reintentar en $_temp0';
  }

  @override
  String errorsErrorWithCode(Object code, Object message) {
    return '$message (Error $code)';
  }

  @override
  String errorsDisconnectServiceFailed(Object service) {
    return 'Error al desconectar $service';
  }

  @override
  String errorsConnectServiceFailed(Object service) {
    return 'Error al conectar $service. Por favor intenta de nuevo.';
  }

  @override
  String get errorsFailedToLoadFriends => 'Error al cargar lista de amigos';

  @override
  String get errorsFailedToAcceptRequest =>
      'Error al aceptar solicitud de amistad';

  @override
  String get errorsFailedToRejectRequest =>
      'Error al rechazar solicitud de amistad';

  @override
  String get errorsFailedToRemoveFriend => 'Error al eliminar amigo';

  @override
  String get errorsSearchFailed =>
      'Búsqueda fallida. Por favor intenta de nuevo.';

  @override
  String get errorsFailedToSendRequest =>
      'Error al enviar solicitud de amistad';

  @override
  String get terminalWebBrowserRequired => 'Navegador web requerido';

  @override
  String get terminalWebBrowserRequiredDescription =>
      'Los enlaces de conexión de terminal solo pueden abrirse en un navegador web por razones de seguridad. Por favor usa el escáner de código QR o abre este enlace en una computadora.';

  @override
  String get terminalProcessingConnection => 'Procesando conexión...';

  @override
  String get terminalInvalidConnectionLink => 'Enlace de conexión inválido';

  @override
  String get terminalInvalidConnectionLinkDescription =>
      'El enlace de conexión falta o es inválido. Por favor verifica la URL e intenta de nuevo.';

  @override
  String get terminalConnectTerminal => 'Conectar terminal';

  @override
  String get terminalRequestDescription =>
      'Una terminal está solicitando conectarse a tu cuenta de Happy Coder. Esto permitirá que la terminal envíe y reciba mensajes de forma segura.';

  @override
  String get terminalConnectionDetails => 'Detalles de conexión';

  @override
  String get terminalPublicKey => 'Clave pública';

  @override
  String get terminalEncryption => 'Cifrado';

  @override
  String get terminalEndToEndEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get terminalAcceptConnection => 'Aceptar conexión';

  @override
  String get terminalConnecting => 'Conectando...';

  @override
  String get terminalReject => 'Rechazar';

  @override
  String get terminalSecurity => 'Seguridad';

  @override
  String get terminalSecurityFooter =>
      'Este enlace de conexión fue procesado de forma segura en tu navegador y nunca fue enviado a ningún servidor. Tus datos privados permanecerán seguros y solo tú puedes descifrar los mensajes.';

  @override
  String get terminalSecurityFooterDevice =>
      'Esta conexión fue procesada de forma segura en tu dispositivo y nunca fue enviada a ningún servidor. Tus datos privados permanecerán seguros y solo tú puedes descifrar los mensajes.';

  @override
  String get terminalClientSideProcessing =>
      'Procesamiento del lado del cliente';

  @override
  String get terminalLinkProcessedLocally =>
      'Enlace procesado localmente en el navegador';

  @override
  String get terminalLinkProcessedOnDevice =>
      'Enlace procesado localmente en el dispositivo';

  @override
  String get sidebarSessionsTitle => 'Terminales';

  @override
  String get sidebarStatusConnected => 'Conectado';

  @override
  String get sidebarStatusConnecting => 'Conectando...';

  @override
  String get sidebarStatusDisconnected => 'Desconectado';

  @override
  String get sidebarStatusError => 'Error';

  @override
  String get commandPalettePlaceholder => 'Escribe un comando o busca...';

  @override
  String get toolViewInput => 'Entrada';

  @override
  String get toolViewOutput => 'Salida';

  @override
  String get toolViewDescription => 'Descripción';

  @override
  String get toolViewInputParams => 'Parámetros de entrada';

  @override
  String get toolViewError => 'Error';

  @override
  String get toolViewCompleted => 'Herramienta completada exitosamente';

  @override
  String get toolViewNoOutput => 'No se produjo ninguna salida';

  @override
  String get toolViewRunning => 'La herramienta está ejecutándose...';

  @override
  String get toolViewRawJsonDevMode => 'JSON sin procesar (modo desarrollo)';

  @override
  String get toolNamesTask => 'Tarea';

  @override
  String get toolNamesTerminal => 'Terminal';

  @override
  String get toolNamesSearchFiles => 'Buscar archivos';

  @override
  String get toolNamesSearch => 'Buscar';

  @override
  String get toolNamesSearchContent => 'Buscar contenido';

  @override
  String get toolNamesListFiles => 'Listar archivos';

  @override
  String get toolNamesPlanProposal => 'Propuesta de plan';

  @override
  String get toolNamesReadFile => 'Leer archivo';

  @override
  String get toolNamesEditFile => 'Editar archivo';

  @override
  String get toolNamesWriteFile => 'Escribir archivo';

  @override
  String get toolNamesFetchUrl => 'Obtener URL';

  @override
  String get toolNamesReadNotebook => 'Leer cuaderno';

  @override
  String get toolNamesEditNotebook => 'Editar cuaderno';

  @override
  String get toolNamesTodoList => 'Lista de tareas';

  @override
  String get toolNamesWebSearch => 'Buscar en web';

  @override
  String get toolNamesReasoning => 'Razonamiento';

  @override
  String get toolNamesApplyChanges => 'Actualizar archivo';

  @override
  String get toolNamesViewDiff => 'Cambios actuales del archivo';

  @override
  String get toolNamesQuestion => 'Pregunta';

  @override
  String toolDescTerminalCmd(String cmd) {
    return 'Terminal(cmd: $cmd)';
  }

  @override
  String toolDescSearchPattern(Object pattern) {
    return 'Buscar(patrón: $pattern)';
  }

  @override
  String toolDescSearchPath(Object basename) {
    return 'Buscar(ruta: $basename)';
  }

  @override
  String toolDescFetchUrlHost(Object host) {
    return 'Obtener URL(url: $host)';
  }

  @override
  String toolDescEditNotebookMode(Object mode, Object path) {
    return 'Editar cuaderno(archivo: $path, modo: $mode)';
  }

  @override
  String toolDescTodoListCount(Object count) {
    return 'Lista de tareas(cuenta: $count)';
  }

  @override
  String toolDescWebSearchQuery(Object query) {
    return 'Buscar en web(consulta: $query)';
  }

  @override
  String toolDescGrepPattern(Object pattern) {
    return 'grep(patrón: $pattern)';
  }

  @override
  String toolDescMultiEditEdits(Object count, Object path) {
    return '$path ($count ediciones)';
  }

  @override
  String toolDescReadingFile(Object file) {
    return 'Leyendo $file';
  }

  @override
  String toolDescWritingFile(Object file) {
    return 'Escribiendo $file';
  }

  @override
  String toolDescModifyingFile(Object file) {
    return 'Modificando $file';
  }

  @override
  String toolDescModifyingFiles(Object count) {
    return 'Modificando $count archivos';
  }

  @override
  String toolDescModifyingMultipleFiles(Object count, Object file) {
    return '$file y $count más';
  }

  @override
  String get toolDescShowingDiff => 'Mostrando cambios';

  @override
  String get filesSearchPlaceholder => 'Buscar archivos...';

  @override
  String get filesDetachedHead => 'HEAD separado';

  @override
  String filesSummary(Object staged, Object unstaged) {
    return '$staged en etapas • $unstaged sin etapas';
  }

  @override
  String get filesNotRepo => 'No es un repositorio git';

  @override
  String get filesNotUnderGit =>
      'Este directorio no está bajo control de versiones git';

  @override
  String get filesSearching => 'Buscando archivos...';

  @override
  String get filesNoFilesFound => 'No se encontraron archivos';

  @override
  String get filesNoFilesInProject => 'No hay archivos en el proyecto';

  @override
  String get filesTryDifferentTerm =>
      'Prueba con un término de búsqueda diferente';

  @override
  String filesSearchResults(int count) {
    return 'Resultados de búsqueda ($count)';
  }

  @override
  String get filesProjectRoot => 'Raíz del proyecto';

  @override
  String filesStagedChanges(Object count) {
    return 'Cambios en etapas ($count)';
  }

  @override
  String filesUnstagedChanges(Object count) {
    return 'Cambios sin etapas ($count)';
  }

  @override
  String filesLoadingFile(Object fileName) {
    return 'Cargando $fileName...';
  }

  @override
  String get filesBinaryFile => 'Archivo binario';

  @override
  String get filesCannotDisplayBinary =>
      'No se puede mostrar el contenido del archivo binario';

  @override
  String get filesDiff => 'Diff';

  @override
  String get filesFile => 'Archivo';

  @override
  String get filesFileEmpty => 'El archivo está vacío';

  @override
  String get filesNoChanges => 'No hay cambios para mostrar';

  @override
  String get profileUserProfile => 'Perfil de usuario';

  @override
  String get profileDetails => 'Detalles';

  @override
  String get profileFirstName => 'Nombre';

  @override
  String get profileLastName => 'Apellido';

  @override
  String get profileUsername => 'Nombre de usuario';

  @override
  String get profileStatus => 'Estado';

  @override
  String get agentPermissionModeTitle => 'MODO DE PERMISO';

  @override
  String get agentPermissionModeDefault => 'Predeterminado';

  @override
  String get agentPermissionModeAcceptEdits => 'Aceptar ediciones';

  @override
  String get agentPermissionModePlan => 'Modo plan';

  @override
  String get agentPermissionModeBypassPermissions => 'Modo Yolo';

  @override
  String get agentPermissionModeBadgeAcceptAllEdits =>
      'Aceptar todas las ediciones';

  @override
  String get agentPermissionModeBadgeBypassAllPermissions =>
      'Omitir todos los permisos';

  @override
  String get agentPermissionModeBadgePlanMode => 'Modo plan';

  @override
  String get agentAgentClaude => 'Claude';

  @override
  String get agentAgentCodex => 'Codex';

  @override
  String get agentAgentGemini => 'Gemini';

  @override
  String get agentModelTitle => 'MODELO';

  @override
  String get agentModelConfigureInCli =>
      'Configura modelos en la configuración del CLI';

  @override
  String agentContextRemaining(int percent) {
    return '$percent% restante';
  }

  @override
  String get agentSuggestionFileLabel => 'ARCHIVO';

  @override
  String get agentSuggestionFolderLabel => 'CARPETA';

  @override
  String get agentNoMachinesAvailable => 'Sin máquinas disponibles';

  @override
  String get updateBannerUpdateAvailable => 'Actualización disponible';

  @override
  String get updateBannerPressToApply =>
      'Presiona para aplicar la actualización';

  @override
  String get updateBannerWhatsNew => 'Novedades';

  @override
  String get updateBannerSeeLatest =>
      'Ver las últimas actualizaciones y mejoras';

  @override
  String get updateBannerNativeUpdateAvailable =>
      'Actualización de aplicación disponible';

  @override
  String get updateBannerTapToUpdateAppStore =>
      'Toca para actualizar en App Store';

  @override
  String get updateBannerTapToUpdatePlayStore =>
      'Toca para actualizar en Play Store';

  @override
  String changelogVersion(int version) {
    return 'Versión $version';
  }

  @override
  String get changelogNoEntriesAvailable =>
      'No hay entradas de registro de cambios disponibles.';

  @override
  String get modalsAuthenticateTerminal => 'Autenticar terminal';

  @override
  String get modalsPasteUrlFromTerminal =>
      'Pega la URL de autenticación de tu terminal';

  @override
  String get modalsDeviceLinkedSuccessfully =>
      'Dispositivo vinculado exitosamente';

  @override
  String get modalsTerminalConnectedSuccessfully =>
      'Terminal conectada exitosamente';

  @override
  String get modalsInvalidAuthUrl => 'URL de autenticación inválida';

  @override
  String get modalsDeveloperMode => 'Modo desarrollador';

  @override
  String get modalsDeveloperModeEnabled => 'Modo desarrollador habilitado';

  @override
  String get modalsDeveloperModeDisabled => 'Modo desarrollador deshabilitado';

  @override
  String get modalsDisconnectGithub => 'Desconectar GitHub';

  @override
  String get modalsDisconnectGithubConfirm =>
      '¿Estás seguro de que deseas desconectar tu cuenta de GitHub?';

  @override
  String modalsDisconnectService(String service) {
    return 'Desconectar $service';
  }

  @override
  String modalsDisconnectServiceConfirm(Object service) {
    return '¿Estás seguro de que deseas desconectar $service de tu cuenta?';
  }

  @override
  String get modalsDisconnect => 'Desconectar';

  @override
  String get modalsFailedToConnectTerminal => 'Error al conectar terminal';

  @override
  String get modalsCameraPermissionsRequiredToConnectTerminal =>
      'Se requieren permisos de cámara para conectar la terminal';

  @override
  String get modalsFailedToLinkDevice => 'Error al vincular dispositivo';

  @override
  String get navigationConnectTerminal => 'Conectar terminal';

  @override
  String get navigationLinkNewDevice => 'Vincular nuevo dispositivo';

  @override
  String get navigationRestoreWithSecretKey => 'Restaurar con clave secreta';

  @override
  String get navigationWhatsNew => 'Novedades';

  @override
  String get navigationFriends => 'Amigos';

  @override
  String get emptyMainScreenReadyToCode => '¿Listo para programar?';

  @override
  String get emptyMainScreenInstallCli => 'Instala el CLI de Happy';

  @override
  String get emptyMainScreenRunIt => 'Ejecútalo';

  @override
  String get emptyMainScreenScanQrCode => 'Escanea el código QR';

  @override
  String get emptyMainScreenOpenCamera => 'Abrir cámara';

  @override
  String get reviewEnjoyingApp => '¿Te gusta la aplicación?';

  @override
  String get reviewFeedbackPrompt => '¡Nos encantaría recibir tus comentarios!';

  @override
  String get reviewYesILoveIt => '¡Sí, me encanta!';

  @override
  String get reviewNotReally => 'No realmente';

  @override
  String itemsCopiedToClipboard(String label) {
    return '$label copiado al portapapeles';
  }

  @override
  String messageSwitchedToMode(String mode) {
    return 'Cambiado a modo $mode';
  }

  @override
  String get messageUnknownEvent => 'Evento desconocido';

  @override
  String messageUsageLimitUntil(Object time) {
    return 'Límite de uso alcanzado hasta $time';
  }

  @override
  String get messageUnknownTime => 'hora desconocida';

  @override
  String get codexPermissionsYesForSession =>
      'Sí, y no preguntar para una sesión';

  @override
  String get codexPermissionsStopAndExplain => 'Detener y explicar qué hacer';

  @override
  String get claudePermissionsYesAllowAllEdits =>
      'Sí, permitir todas las ediciones durante esta sesión';

  @override
  String get claudePermissionsYesForTool =>
      'Sí, no preguntar de nuevo para esta herramienta';

  @override
  String get claudePermissionsNoTellClaude => 'No, y proporcionar comentarios';

  @override
  String get textSelectionSelectText => 'Seleccionar rango de texto';

  @override
  String get textSelectionTitle => 'Seleccionar texto';

  @override
  String get textSelectionNoTextProvided => 'No se proporcionó texto';

  @override
  String get textSelectionTextNotFound => 'Texto no encontrado o expirado';

  @override
  String get textSelectionTextCopied => 'Texto copiado al portapapeles';

  @override
  String get textSelectionFailedToCopy =>
      'Error al copiar texto al portapapeles';

  @override
  String get textSelectionNoTextToCopy => 'No hay texto disponible para copiar';

  @override
  String get markdownCodeCopied => 'Código copiado';

  @override
  String get markdownCopyFailed => 'Error al copiar';

  @override
  String get markdownMermaidRenderFailed =>
      'Error al renderizar diagrama de mermaid';

  @override
  String get artifactsTitle => 'Artefactos';

  @override
  String get artifactsCountSingular => '1 artefacto';

  @override
  String artifactsCountPlural(int count) {
    return '$count artefactos';
  }

  @override
  String get artifactsEmpty => 'Aún no hay artefactos';

  @override
  String get artifactsEmptyDescription =>
      'Crea tu primer artefacto para comenzar';

  @override
  String get artifactsNew => 'Nuevo artefacto';

  @override
  String get artifactsEdit => 'Editar artefacto';

  @override
  String get artifactsDelete => 'Eliminar';

  @override
  String get artifactsUpdateError =>
      'Error al actualizar artefacto. Por favor intenta de nuevo.';

  @override
  String get artifactsNotFound => 'Artefacto no encontrado';

  @override
  String get artifactsDiscardChanges => '¿Descartar cambios?';

  @override
  String get artifactsDiscardChangesDescription =>
      'Tienes cambios sin guardar. ¿Estás seguro de que deseas descartarlos?';

  @override
  String get artifactsDeleteConfirm => '¿Eliminar artefacto?';

  @override
  String get artifactsDeleteConfirmDescription =>
      'Esta acción no se puede deshacer';

  @override
  String get artifactsTitleLabel => 'TÍTULO';

  @override
  String get artifactsTitlePlaceholder => 'Ingresa un título para tu artefacto';

  @override
  String get artifactsBodyLabel => 'CONTENIDO';

  @override
  String get artifactsBodyPlaceholder => 'Escribe tu contenido aquí...';

  @override
  String get artifactsEmptyFieldsError =>
      'Por favor ingresa un título o contenido';

  @override
  String get artifactsCreateError =>
      'Error al crear artefacto. Por favor intenta de nuevo.';

  @override
  String get artifactsSave => 'Guardar';

  @override
  String get artifactsSaving => 'Guardando...';

  @override
  String get artifactsLoading => 'Cargando artefactos...';

  @override
  String get artifactsError => 'Error al cargar artefacto';

  @override
  String get friendsTitle => 'Amigos';

  @override
  String get friendsManageFriends => 'Administra tus amigos y conexiones';

  @override
  String get friendsSearchTitle => 'Buscar amigos';

  @override
  String get friendsPendingRequests => 'Solicitudes de amistad';

  @override
  String get friendsMyFriends => 'Mis amigos';

  @override
  String get friendsNoFriendsYet => 'Aún no tienes amigos';

  @override
  String get friendsFindFriends => 'Buscar amigos';

  @override
  String get friendsRemove => 'Eliminar';

  @override
  String get friendsPendingRequest => 'Pendiente';

  @override
  String friendsSentOn(String date) {
    return 'Enviado el $date';
  }

  @override
  String get friendsAccept => 'Aceptar';

  @override
  String get friendsReject => 'Rechazar';

  @override
  String get friendsAddFriend => 'Agregar amigo';

  @override
  String get friendsAlreadyFriends => 'Ya son amigos';

  @override
  String get friendsRequestPending => 'Solicitud pendiente';

  @override
  String get friendsSearchInstructions =>
      'Ingresa un nombre de usuario para buscar amigos';

  @override
  String get friendsSearchPlaceholder => 'Ingresa nombre de usuario...';

  @override
  String get friendsSearching => 'Buscando...';

  @override
  String get friendsUserNotFound => 'Usuario no encontrado';

  @override
  String get friendsNoUserFound =>
      'No se encontró ningún usuario con ese nombre de usuario';

  @override
  String get friendsCheckUsername =>
      'Por favor verifica el nombre de usuario e intenta de nuevo';

  @override
  String get friendsHowToFind => 'Cómo encontrar amigos';

  @override
  String get friendsFindInstructions =>
      'Busca amigos por su nombre de usuario. Tanto tú como tu amigo necesitan tener GitHub conectado para enviar solicitudes de amistad.';

  @override
  String get friendsRequestSent => '¡Solicitud de amistad enviada!';

  @override
  String get friendsRequestAccepted => '¡Solicitud de amistad aceptada!';

  @override
  String get friendsRequestRejected => 'Solicitud de amistad rechazada';

  @override
  String get friendsFriendRemoved => 'Amigo eliminado';

  @override
  String get friendsConfirmRemove => 'Eliminar amigo';

  @override
  String get friendsConfirmRemoveMessage =>
      '¿Estás seguro de que deseas eliminar a este amigo?';

  @override
  String get friendsCannotAddYourself =>
      'No puedes enviar una solicitud de amistad a ti mismo';

  @override
  String get friendsBothMustHaveGithub =>
      'Ambos usuarios deben tener GitHub conectado para ser amigos';

  @override
  String get friendsStatusNone => 'No conectado';

  @override
  String get friendsStatusRequested => 'Solicitud enviada';

  @override
  String get friendsStatusPending => 'Solicitud pendiente';

  @override
  String get friendsStatusFriend => 'Amigos';

  @override
  String get friendsStatusRejected => 'Rechazado';

  @override
  String get friendsAcceptRequest => 'Aceptar solicitud';

  @override
  String get friendsRemoveFriend => 'Eliminar amigo';

  @override
  String friendsRemoveFriendConfirm(Object name) {
    return '¿Estás seguro de que deseas eliminar a $name como amigo?';
  }

  @override
  String friendsRequestSentDescription(Object name) {
    return 'Tu solicitud de amistad ha sido enviada a $name';
  }

  @override
  String get friendsRequestFriendship => 'Solicitar amistad';

  @override
  String get friendsCancelRequest => 'Cancelar solicitud de amistad';

  @override
  String friendsCancelRequestConfirm(Object name) {
    return '¿Cancelar tu solicitud de amistad a $name?';
  }

  @override
  String get friendsDenyRequest => 'Denegar amistad';

  @override
  String friendsNowFriendsWith(Object name) {
    return 'Ahora eres amigo de $name';
  }

  @override
  String feedFriendRequestFrom(String name) {
    return '$name te envió una solicitud de amistad';
  }

  @override
  String get feedFriendRequestGeneric => 'Nueva solicitud de amistad';

  @override
  String feedFriendAccepted(Object name) {
    return 'Ahora eres amigo de $name';
  }

  @override
  String get feedFriendAcceptedGeneric => 'Solicitud de amistad aceptada';

  @override
  String get usageToday => 'Hoy';

  @override
  String get usageLast7Days => 'Últimos 7 días';

  @override
  String get usageLast30Days => 'Últimos 30 días';

  @override
  String get usageTotalTokens => 'Tokens totales';

  @override
  String get usageTotalCost => 'Costo total';

  @override
  String get usageTokens => 'Tokens';

  @override
  String get usageCost => 'Costo';

  @override
  String get usageUsageOverTime => 'Uso a lo largo del tiempo';

  @override
  String get usageByModel => 'Por modelo';

  @override
  String get usageNoData => 'No hay datos de uso disponibles';

  @override
  String get offlineBannerNoConnection => 'No internet connection';

  @override
  String get offlineBannerReconnecting => 'Reconnecting...';
}
