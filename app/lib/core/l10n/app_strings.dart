class AppStrings {
  // App & Navigation
  final String appTitle;
  final String navSchedule;
  final String navAiAssistant;
  final String navSettings;
  final String searchPlaceholder;

  // Task Views
  final String viewToday;
  final String viewThisWeek;
  final String viewTimeline;
  final String viewCalendar;
  final String formatMonth;
  final String formatTwoWeeks;
  final String formatWeek;
  final String addTaskOnDay;
  final String noTasksForDay;
  final String addToGoogleCalendar;
  final String filterAll;
  final String filterPending;
  final String filterInProgress;
  final String filterCompleted;
  final String filterCancelled;

  // Priorities
  final String priorityAll;
  final String priorityUrgent;
  final String priorityHigh;
  final String priorityMedium;
  final String priorityLow;

  // Task Card & Details
  final String taskSourceVoice;
  final String taskSourceManual;
  final String reminderLabel;
  final String durationLabel;
  final String markComplete;
  final String markIncomplete;
  final String editTask;
  final String deleteTask;
  final String noTasksToday;
  final String noTasksFound;
  final String tasksCount;

  // Task Form / Modal
  final String addTask;
  final String editTaskTitle;
  final String taskTitleLabel;
  final String taskTitleHint;
  final String taskDescLabel;
  final String taskDescHint;
  final String taskDateLabel;
  final String startTimeLabel;
  final String endTimeLabel;
  final String priorityLabel;
  final String reminderOffsetLabel;
  final String saveButton;
  final String cancelButton;
  final String validationTitleRequired;
  final String validationTimeOrder;
  final String conflictDetectedWarning;

  // AI Assistant Chat & Voice
  final String aiAssistantTitle;
  final String aiWelcomeMessage;
  final String aiTypingHint;
  final String micHoldToSpeak;
  final String micTapToRecord;
  final String recordingTimer;
  final String cancelRecording;
  final String sendRecording;
  final String micPermissionDenied;
  final String voiceSimulatedNotice;
  final String quickPromptsLabel;

  // Quick Prompt Chips
  final String quickPrompt1;
  final String quickPrompt2;
  final String quickPrompt3;
  final String quickPrompt4;
  final String quickPrompt5;

  // Structured AI Cards
  final String cardTaskCreatedTitle;
  final String cardUndo;
  final String cardEdit;
  final String cardConflictTitle;
  final String cardConflictDesc;
  final String cardFreeSlotsTitle;
  final String cardAvailableSlotsHeader;
  final String cardScheduleHere;
  final String cardDeleteConfirmTitle;
  final String cardDeleteConfirmDesc;
  final String cardConfirmDelete;
  final String cardCancel;
  final String actionCompletedNotification;
  final String actionUndoneNotification;

  // Settings
  final String settingsTitle;
  final String sectionPreferences;
  final String sectionScheduleRules;
  final String sectionAccount;
  final String languageLabel;
  final String languageArabic;
  final String languageEnglish;
  final String themeLabel;
  final String themeDark;
  final String themeLight;
  final String themeSystem;
  final String workingHoursLabel;
  final String workingHoursDesc;
  final String workStartLabel;
  final String workEndLabel;
  final String defaultReminderLabel;
  final String timezoneLabel;
  final String notificationsLabel;
  final String soundEffectsLabel;
  final String vibrationLabel;
  final String resetDemoData;
  final String resetSuccess;
  final String signOutButton;
  final String userProfileName;
  final String userProfileEmail;

  // Auth Screens
  final String loginTitle;
  final String loginSubtitle;
  final String registerTitle;
  final String registerSubtitle;
  final String emailLabel;
  final String emailHint;
  final String passwordLabel;
  final String passwordHint;
  final String nameLabel;
  final String nameHint;
  final String rememberMe;
  final String forgotPassword;
  final String signInButton;
  final String signUpButton;
  final String enterDemoButton;
  final String alreadyHaveAccount;
  final String dontHaveAccount;
  final String authGuestNotice;

  // Auth Errors & Validation
  final String authErrorInvalidCredentials;
  final String authErrorEmailExists;
  final String authErrorValidation;
  final String authErrorConnection;
  final String validationEmailRequired;
  final String validationEmailInvalid;
  final String validationPasswordRequired;
  final String validationPasswordTooShort;
  final String validationNameRequired;
  final String validationConfirmPasswordRequired;
  final String validationPasswordsDoNotMatch;
  final String confirmPasswordLabel;
  final String confirmPasswordHint;

  const AppStrings({
    required this.appTitle,
    required this.navSchedule,
    required this.navAiAssistant,
    required this.navSettings,
    required this.searchPlaceholder,
    required this.viewToday,
    required this.viewThisWeek,
    required this.viewTimeline,
    required this.viewCalendar,
    required this.formatMonth,
    required this.formatTwoWeeks,
    required this.formatWeek,
    required this.addTaskOnDay,
    required this.noTasksForDay,
    required this.addToGoogleCalendar,
    required this.filterAll,
    required this.filterPending,
    required this.filterInProgress,
    required this.filterCompleted,
    required this.filterCancelled,
    required this.priorityAll,
    required this.priorityUrgent,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
    required this.taskSourceVoice,
    required this.taskSourceManual,
    required this.reminderLabel,
    required this.durationLabel,
    required this.markComplete,
    required this.markIncomplete,
    required this.editTask,
    required this.deleteTask,
    required this.noTasksToday,
    required this.noTasksFound,
    required this.tasksCount,
    required this.addTask,
    required this.editTaskTitle,
    required this.taskTitleLabel,
    required this.taskTitleHint,
    required this.taskDescLabel,
    required this.taskDescHint,
    required this.taskDateLabel,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.priorityLabel,
    required this.reminderOffsetLabel,
    required this.saveButton,
    required this.cancelButton,
    required this.validationTitleRequired,
    required this.validationTimeOrder,
    required this.conflictDetectedWarning,
    required this.aiAssistantTitle,
    required this.aiWelcomeMessage,
    required this.aiTypingHint,
    required this.micHoldToSpeak,
    required this.micTapToRecord,
    required this.recordingTimer,
    required this.cancelRecording,
    required this.sendRecording,
    required this.micPermissionDenied,
    required this.voiceSimulatedNotice,
    required this.quickPromptsLabel,
    required this.quickPrompt1,
    required this.quickPrompt2,
    required this.quickPrompt3,
    required this.quickPrompt4,
    required this.quickPrompt5,
    required this.cardTaskCreatedTitle,
    required this.cardUndo,
    required this.cardEdit,
    required this.cardConflictTitle,
    required this.cardConflictDesc,
    required this.cardFreeSlotsTitle,
    required this.cardAvailableSlotsHeader,
    required this.cardScheduleHere,
    required this.cardDeleteConfirmTitle,
    required this.cardDeleteConfirmDesc,
    required this.cardConfirmDelete,
    required this.cardCancel,
    required this.actionCompletedNotification,
    required this.actionUndoneNotification,
    required this.settingsTitle,
    required this.sectionPreferences,
    required this.sectionScheduleRules,
    required this.sectionAccount,
    required this.languageLabel,
    required this.languageArabic,
    required this.languageEnglish,
    required this.themeLabel,
    required this.themeDark,
    required this.themeLight,
    required this.themeSystem,
    required this.workingHoursLabel,
    required this.workingHoursDesc,
    required this.workStartLabel,
    required this.workEndLabel,
    required this.defaultReminderLabel,
    required this.timezoneLabel,
    required this.notificationsLabel,
    required this.soundEffectsLabel,
    required this.vibrationLabel,
    required this.resetDemoData,
    required this.resetSuccess,
    required this.signOutButton,
    required this.userProfileName,
    required this.userProfileEmail,
    required this.loginTitle,
    required this.loginSubtitle,
    required this.registerTitle,
    required this.registerSubtitle,
    required this.emailLabel,
    required this.emailHint,
    required this.passwordLabel,
    required this.passwordHint,
    required this.nameLabel,
    required this.nameHint,
    required this.rememberMe,
    required this.forgotPassword,
    required this.signInButton,
    required this.signUpButton,
    required this.enterDemoButton,
    required this.alreadyHaveAccount,
    required this.dontHaveAccount,
    required this.authGuestNotice,
    required this.authErrorInvalidCredentials,
    required this.authErrorEmailExists,
    required this.authErrorValidation,
    required this.authErrorConnection,
    required this.validationEmailRequired,
    required this.validationEmailInvalid,
    required this.validationPasswordRequired,
    required this.validationPasswordTooShort,
    required this.validationNameRequired,
    required this.validationConfirmPasswordRequired,
    required this.validationPasswordsDoNotMatch,
    required this.confirmPasswordLabel,
    required this.confirmPasswordHint,
  });

  static const AppStrings ar = AppStrings(
    appTitle: 'سيا',
    navSchedule: 'الجدول',
    navAiAssistant: 'المساعد الذكي',
    navSettings: 'الإعدادات',
    searchPlaceholder: 'بحث في المهام...',
    viewToday: 'اليوم',
    viewThisWeek: 'هذا الأسبوع',
    viewTimeline: 'المخطط الزمني',
    viewCalendar: 'التقويم',
    formatMonth: 'شهر',
    formatTwoWeeks: 'أسبوعان',
    formatWeek: 'أسبوع',
    addTaskOnDay: 'إضافة مهمة في هذا اليوم',
    noTasksForDay: 'لا توجد مهام مجدولة في هذا اليوم',
    addToGoogleCalendar: 'إضافة لتقويم جوجل',
    filterAll: 'الكل',
    filterPending: 'قيد الانتظار',
    filterInProgress: 'جارية',
    filterCompleted: 'مكتملة',
    filterCancelled: 'ملغاة',
    priorityAll: 'كل الأولويات',
    priorityUrgent: 'عاجل',
    priorityHigh: 'مرتفع',
    priorityMedium: 'متوسط',
    priorityLow: 'منخفض',
    taskSourceVoice: 'صوتي',
    taskSourceManual: 'يدوي',
    reminderLabel: 'تذكير',
    durationLabel: 'المدة',
    markComplete: 'تحديد كمكتمل',
    markIncomplete: 'إعادة للانتظار',
    editTask: 'تعديل المهمة',
    deleteTask: 'حذف المهمة',
    noTasksToday: 'لا توجد مهام مجدولة لليوم! استمتع بوقتك.',
    noTasksFound: 'لم يتم العثور على مهام مطابقة.',
    tasksCount: 'مهام',
    addTask: 'إضافة مهمة جديدة',
    editTaskTitle: 'تعديل المهمة',
    taskTitleLabel: 'عنوان المهمة',
    taskTitleHint: 'مثال: مراجعة خطة التسويق الربع سنوية',
    taskDescLabel: 'التفاصيل والملاحظات (اختياري)',
    taskDescHint: 'أضف أي تفاصيل أو روابط هامة...',
    taskDateLabel: 'التاريخ',
    startTimeLabel: 'وقت البدء',
    endTimeLabel: 'وقت الانتهاء',
    priorityLabel: 'مستوى الأولوية',
    reminderOffsetLabel: 'التذكير المسبق',
    saveButton: 'حفظ المهمة',
    cancelButton: 'إلغاء',
    validationTitleRequired: 'يرجى إدخال عنوان المهمة',
    validationTimeOrder: 'وقت الانتهاء يجب أن يكون بعد وقت البدء',
    conflictDetectedWarning: 'تنبيه: الوقت يتعارض مع مهمة مجدولة بالفعل!',
    aiAssistantTitle: 'المساعد الذكي الصوتي',
    aiWelcomeMessage: 'أهلاً بك! أنا مساعدك الذكي لتنظيم الوقت. يمكنك التحدث معي صوتياً أو كتابياً لتنظيم جدولك، فحص أوقات الفراغ، وتفادي التعارضات.',
    aiTypingHint: 'تحدث أو اكتب طلبك (مثال: أنا فاضي إمتى النهاردة؟)...',
    micHoldToSpeak: 'اضغط للتحدث بالصوت',
    micTapToRecord: 'بدء التسجيل الصوتي',
    recordingTimer: 'جارِ الاستماع...',
    cancelRecording: 'إلغاء',
    sendRecording: 'إرسال التسجيل',
    micPermissionDenied: 'يتطلب التطبيق إذن الميكروفون للتسجيل الصوتي.',
    voiceSimulatedNotice: 'تمت محاكاة الإدخال الصوتي بنجاح في وضع الويب.',
    quickPromptsLabel: 'أوامر مقترحة سريعة:',
    quickPrompt1: 'عندي تاسكات إيه النهاردة؟',
    quickPrompt2: 'أنا فاضي إمتى النهاردة؟',
    quickPrompt3: 'ضيف مراجعة كود بكرة الساعة 3 الظهر',
    quickPrompt4: 'عندي اجتماع الجمعة الساعة 1 الظهر',
    quickPrompt5: 'فكرني بمكالمة العميل بعد ساعة',
    cardTaskCreatedTitle: 'تم إنشاء المهمة بنجاح',
    cardUndo: 'تراجع',
    cardEdit: 'تعديل',
    cardConflictTitle: 'تنبيه: يوجد تعارض في المواعيد!',
    cardConflictDesc: 'الوقت المطلوب يتعارض مع مهمة أخرى قائمة. إليك الفترات المتاحة البديلة:',
    cardFreeSlotsTitle: 'الفترات الزمنية المتاحة',
    cardAvailableSlotsHeader: 'الأوقات الشاغرة المحسوبة في ساعات عملك:',
    cardScheduleHere: 'حجز في هذا الوقت',
    cardDeleteConfirmTitle: 'تأكيد حذف المهمة',
    cardDeleteConfirmDesc: 'هل أنت متأكد من رغبتك في حذف هذه المهمة نهائياً؟',
    cardConfirmDelete: 'نعم، حذف',
    cardCancel: 'إلغاء',
    actionCompletedNotification: 'تم تنفيذ الإجراء بنجاح',
    actionUndoneNotification: 'تم التراجع عن الإجراء',
    settingsTitle: 'الإعدادات والتفضيلات',
    sectionPreferences: 'المظهر واللغة',
    sectionScheduleRules: 'قواعد الجدولة والمواعيد',
    sectionAccount: 'الحساب والجلسة',
    languageLabel: 'لغة التطبيق',
    languageArabic: 'العربية (RTL)',
    languageEnglish: 'English (LTR)',
    themeLabel: 'نمط المظهر',
    themeDark: 'الوضع الليلي (Linear Dark)',
    themeLight: 'الوضع الفاتح (Clean Light)',
    themeSystem: 'حسب النظام',
    workingHoursLabel: 'ساعات العمل الرسمية',
    workingHoursDesc: 'تُستخدم لحساب فترات الفراغ واقتراح المواعيد غير المتعارضة',
    workStartLabel: 'بداية العمل',
    workEndLabel: 'نهاية العمل',
    defaultReminderLabel: 'التذكير الافتراضي المسبق',
    timezoneLabel: 'المنطقة الزمنية',
    notificationsLabel: 'تفعيل الإشعارات والتنبيهات',
    soundEffectsLabel: 'المؤثرات الصوتية',
    vibrationLabel: 'الاهتزاز عند التنبيه',
    resetDemoData: 'إعادة تعيين البيانات التجريبية',
    resetSuccess: 'تمت استعادة البيانات التجريبية بنجاح',
    signOutButton: 'تسجيل الخروج',
    userProfileName: 'أحمد سمير',
    userProfileEmail: 'ahmed@example.com',
    loginTitle: 'تسجيل الدخول',
    loginSubtitle: 'مرحباً بك مجدداً في سيا (Sia)',
    registerTitle: 'إنشاء حساب جديد',
    registerSubtitle: 'ابدأ تنظيم يومك بذكاء وبصوتك مع سيا',
    emailLabel: 'البريد الإلكتروني',
    emailHint: 'name@example.com',
    passwordLabel: 'كلمة المرور',
    passwordHint: '••••••••',
    nameLabel: 'الاسم الكامل',
    nameHint: 'أحمد سمير',
    rememberMe: 'تذكرني على هذا الجهاز',
    forgotPassword: 'نسيت كلمة المرور؟',
    signInButton: 'دخول',
    signUpButton: 'إنشاء الحساب',
    enterDemoButton: 'الدخول المباشر لبيئة العرض (Demo)',
    alreadyHaveAccount: 'لديك حساب بالفعل؟ تسجيل الدخول',
    dontHaveAccount: 'ليس لديك حساب؟ إنشاء حساب جديد',
    authGuestNotice: 'بيئة تجريبية جاهزة للاختبار الفوري دون الحاجة لتسجيل.',
    confirmPasswordLabel: 'تأكيد كلمة المرور',
    confirmPasswordHint: '••••••••',
    authErrorInvalidCredentials: 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    authErrorEmailExists: 'هذا الحساب مستخدم من قبل. جرّب تسجيل الدخول أو استخدم بريداً آخر.',
    authErrorValidation: 'يرجى التحقق من صحة البيانات المدخلة.',
    authErrorConnection: 'تعذر الاتصال بالسيرفر، تأكد من تشغيل الخادم وحاول مرة أخرى.',
    validationEmailRequired: 'يرجى إدخال البريد الإلكتروني',
    validationEmailInvalid: 'يرجى إدخال بريد إلكتروني صحيح',
    validationPasswordRequired: 'يرجى إدخال كلمة المرور',
    validationPasswordTooShort: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
    validationNameRequired: 'يرجى إدخال الاسم بالكامل',
    validationConfirmPasswordRequired: 'يرجى تأكيد كلمة المرور',
    validationPasswordsDoNotMatch: 'كلمتا المرور غير متطابقتين',
  );

  static const AppStrings en = AppStrings(
    appTitle: 'Sia',
    navSchedule: 'Schedule',
    navAiAssistant: 'AI Assistant',
    navSettings: 'Settings',
    searchPlaceholder: 'Search tasks...',
    viewToday: 'Today',
    viewThisWeek: 'This Week',
    viewTimeline: 'Timeline',
    viewCalendar: 'Calendar',
    formatMonth: 'Month',
    formatTwoWeeks: '2 Weeks',
    formatWeek: 'Week',
    addTaskOnDay: 'Add task on this day',
    noTasksForDay: 'No tasks scheduled for this day',
    addToGoogleCalendar: 'Add to Google Calendar',
    filterAll: 'All',
    filterPending: 'Pending',
    filterInProgress: 'In Progress',
    filterCompleted: 'Completed',
    filterCancelled: 'Cancelled',
    priorityAll: 'All Priorities',
    priorityUrgent: 'Urgent',
    priorityHigh: 'High',
    priorityMedium: 'Medium',
    priorityLow: 'Low',
    taskSourceVoice: 'Voice',
    taskSourceManual: 'Manual',
    reminderLabel: 'Reminder',
    durationLabel: 'Duration',
    markComplete: 'Mark Complete',
    markIncomplete: 'Mark Incomplete',
    editTask: 'Edit Task',
    deleteTask: 'Delete Task',
    noTasksToday: 'No tasks scheduled for today! Enjoy your free time.',
    noTasksFound: 'No matching tasks found.',
    tasksCount: 'tasks',
    addTask: 'Add New Task',
    editTaskTitle: 'Edit Task',
    taskTitleLabel: 'Task Title',
    taskTitleHint: 'e.g., Q4 Budget & Roadmap Review',
    taskDescLabel: 'Notes & Details (optional)',
    taskDescHint: 'Add any links, agenda or notes...',
    taskDateLabel: 'Date',
    startTimeLabel: 'Start Time',
    endTimeLabel: 'End Time',
    priorityLabel: 'Priority Level',
    reminderOffsetLabel: 'Reminder Before',
    saveButton: 'Save Task',
    cancelButton: 'Cancel',
    validationTitleRequired: 'Please enter a task title',
    validationTimeOrder: 'End time must be after start time',
    conflictDetectedWarning: 'Warning: Time overlaps with an existing task!',
    aiAssistantTitle: 'Voice AI Task Assistant',
    aiWelcomeMessage: 'Welcome! I am your AI Schedule Assistant. You can speak or type to manage tasks, scan free slots, and resolve calendar conflicts seamlessly.',
    aiTypingHint: 'Speak or type a request (e.g., When am I free today?)...',
    micHoldToSpeak: 'Press to speak',
    micTapToRecord: 'Start voice recording',
    recordingTimer: 'Listening...',
    cancelRecording: 'Cancel',
    sendRecording: 'Send Recording',
    micPermissionDenied: 'Microphone permission is required for voice commands.',
    voiceSimulatedNotice: 'Simulated voice input processed successfully on Web.',
    quickPromptsLabel: 'Quick suggestions:',
    quickPrompt1: 'What tasks do I have today?',
    quickPrompt2: 'When am I free today?',
    quickPrompt3: 'Add code review tomorrow at 3 PM',
    quickPrompt4: 'Schedule team meeting Friday at 1 PM',
    quickPrompt5: 'Remind me of client follow-up in 1 hour',
    cardTaskCreatedTitle: 'Task Created Successfully',
    cardUndo: 'Undo',
    cardEdit: 'Edit',
    cardConflictTitle: 'Schedule Conflict Detected!',
    cardConflictDesc: 'The requested time overlaps with an existing event. Here are open alternative slots:',
    cardFreeSlotsTitle: 'Available Free Windows',
    cardAvailableSlotsHeader: 'Free gaps calculated within your working hours:',
    cardScheduleHere: 'Book This Slot',
    cardDeleteConfirmTitle: 'Confirm Task Deletion',
    cardDeleteConfirmDesc: 'Are you sure you want to permanently delete this task?',
    cardConfirmDelete: 'Yes, Delete',
    cardCancel: 'Cancel',
    actionCompletedNotification: 'Action completed successfully',
    actionUndoneNotification: 'Action undone',
    settingsTitle: 'Settings & Preferences',
    sectionPreferences: 'Appearance & Language',
    sectionScheduleRules: 'Scheduling & Working Hours',
    sectionAccount: 'Account & Session',
    languageLabel: 'Language',
    languageArabic: 'العربية (Arabic RTL)',
    languageEnglish: 'English (LTR)',
    themeLabel: 'Theme Mode',
    themeDark: 'Dark Mode (Linear Dark)',
    themeLight: 'Light Mode (Clean Light)',
    themeSystem: 'System Default',
    workingHoursLabel: 'Working Hours Range',
    workingHoursDesc: 'Used to calculate free windows and suggest conflict-free slots',
    workStartLabel: 'Work Start',
    workEndLabel: 'Work End',
    defaultReminderLabel: 'Default Reminder Offset',
    timezoneLabel: 'Timezone',
    notificationsLabel: 'Push Notifications',
    soundEffectsLabel: 'Sound Effects',
    vibrationLabel: 'Vibrate on Alerts',
    resetDemoData: 'Reset Demo Data',
    resetSuccess: 'Demo data has been restored to default',
    signOutButton: 'Sign Out',
    userProfileName: 'Ahmed Samir',
    userProfileEmail: 'ahmed@example.com',
    loginTitle: 'Welcome Back',
    loginSubtitle: 'Sign in to access your Sia AI schedule',
    registerTitle: 'Create an Account',
    registerSubtitle: 'Start organizing your schedule with your voice and Sia',
    emailLabel: 'Email Address',
    emailHint: 'name@example.com',
    passwordLabel: 'Password',
    passwordHint: '••••••••',
    nameLabel: 'Full Name',
    nameHint: 'Ahmed Samir',
    rememberMe: 'Remember me on this device',
    forgotPassword: 'Forgot password?',
    signInButton: 'Sign In',
    signUpButton: 'Sign Up',
    enterDemoButton: 'Enter Demo Workspace',
    alreadyHaveAccount: 'Already have an account? Sign In',
    dontHaveAccount: 'Don\'t have an account? Sign Up',
    authGuestNotice: 'Demo mode is active. You can explore all features immediately.',
    confirmPasswordLabel: 'Confirm Password',
    confirmPasswordHint: '••••••••',
    authErrorInvalidCredentials: 'Incorrect email or password.',
    authErrorEmailExists: 'This email is already registered. Try signing in or use another email.',
    authErrorValidation: 'Please check your input details.',
    authErrorConnection: 'Cannot connect to the server. Please make sure the backend is running.',
    validationEmailRequired: 'Email is required',
    validationEmailInvalid: 'Please enter a valid email address',
    validationPasswordRequired: 'Password is required',
    validationPasswordTooShort: 'Password must be at least 6 characters',
    validationNameRequired: 'Full name is required',
    validationConfirmPasswordRequired: 'Please confirm your password',
    validationPasswordsDoNotMatch: 'Passwords do not match',
  );
}
