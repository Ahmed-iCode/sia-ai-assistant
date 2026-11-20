import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/reminder_model.dart';
import '../models/free_slot_model.dart';
import '../models/chat_message_model.dart';
import '../models/ai_action_card_model.dart';
import 'task_repository.dart';

class MockTaskRepository implements TaskRepository {
  static final MockTaskRepository _instance = MockTaskRepository._internal();
  factory MockTaskRepository() => _instance;

  final List<TaskModel> _tasks = [];
  final _uuid = const Uuid();

  MockTaskRepository._internal() {
    _seedInitialTasks();
  }

  void _seedInitialTasks() {
    _tasks.clear();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _tasks.addAll([
      TaskModel(
        id: 'seed-task-1',
        title: 'مراجعة تقرير الميزانية الربع سنوي',
        description: 'مناقشة خطة التوسع واعتماد ميزانية الأدوات السحابية الجديدة.',
        startTime: today.add(const Duration(hours: 10)),
        endTime: today.add(const Duration(hours: 11, minutes: 30)),
        priority: TaskPriority.urgent,
        status: TaskStatus.completed,
        isVoiceCreated: false,
        tags: ['Finance', 'Q4'],
        reminders: [
          ReminderModel(
            id: 'rem-1',
            taskId: 'seed-task-1',
            remindAt: today.add(const Duration(hours: 9, minutes: 45)),
            offsetMinutes: 15,
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      TaskModel(
        id: 'seed-task-2',
        title: 'اجتماع فريق التطوير والذكاء الاصطناعي',
        description: 'مراجعة معمارية تطبيق الفلاتر ونموذج التعرف الصوتي على الويب.',
        startTime: today.add(const Duration(hours: 13)),
        endTime: today.add(const Duration(hours: 14)),
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        isVoiceCreated: true,
        tags: ['Flutter', 'AI', 'Core'],
        reminders: [
          ReminderModel(
            id: 'rem-2',
            taskId: 'seed-task-2',
            remindAt: today.add(const Duration(hours: 12, minutes: 30)),
            offsetMinutes: 30,
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now,
      ),
      TaskModel(
        id: 'seed-task-3',
        title: 'جلسة كود مع فريق الواجهات',
        description: 'مراجعة المكونات والتأكد من انضباط RTL / LTR والخطوط.',
        startTime: today.add(const Duration(hours: 15, minutes: 30)),
        endTime: today.add(const Duration(hours: 16, minutes: 30)),
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        isVoiceCreated: false,
        tags: ['UI', 'Review'],
        reminders: [
          ReminderModel(
            id: 'rem-3',
            taskId: 'seed-task-3',
            remindAt: today.add(const Duration(hours: 15, minutes: 0)),
            offsetMinutes: 30,
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now,
      ),
      TaskModel(
        id: 'seed-task-4',
        title: 'شراء مستلزمات المكتب والمعدات',
        description: 'شراء بطاريات للميكروفون وكوابل شحن إضافية.',
        startTime: today.add(const Duration(hours: 18)),
        endTime: today.add(const Duration(hours: 18, minutes: 45)),
        priority: TaskPriority.low,
        status: TaskStatus.pending,
        isVoiceCreated: false,
        tags: ['Errands'],
        reminders: [],
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now,
      ),
      TaskModel(
        id: 'seed-task-5',
        title: 'مكالمة متابعة العميل',
        description: 'استعراض النموذج الأولي للواجهة وتأكيد تاريخ إطلاق المرحلة الثانية.',
        startTime: today.add(const Duration(hours: 20)),
        endTime: today.add(const Duration(hours: 20, minutes: 30)),
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        isVoiceCreated: true,
        tags: ['Client', 'Sync'],
        reminders: [
          ReminderModel(
            id: 'rem-5',
            taskId: 'seed-task-5',
            remindAt: today.add(const Duration(hours: 19, minutes: 30)),
            offsetMinutes: 30,
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      ),
      // Tomorrow task
      TaskModel(
        id: 'seed-task-6',
        title: 'اختبار تجربة المستخدم مع العينة الميدانية',
        description: 'جمع ملاحظات الأداء والتأكد من التجاوب على المتصفح والهواتف.',
        startTime: today.add(const Duration(days: 1, hours: 11)),
        endTime: today.add(const Duration(days: 1, hours: 12, minutes: 30)),
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        isVoiceCreated: false,
        tags: ['Testing'],
        reminders: [],
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  @override
  Future<void> resetDemoData() async {
    await Future.delayed(const Duration(milliseconds: 250));
    _seedInitialTasks();
  }

  @override
  Future<List<TaskModel>> getTasks({DateTime? date}) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (date == null) {
      final sorted = List<TaskModel>.from(_tasks)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return sorted;
    }

    final targetDate = DateTime(date.year, date.month, date.day);
    final filtered = _tasks.where((t) {
      final taskDate = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
      return taskDate.isAtSameMomentAs(targetDate);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return filtered;
  }

  @override
  Future<TaskModel> getTaskById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _tasks.firstWhere((t) => t.id == id);
  }

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final newTask = task.copyWith(
      id: task.id.isEmpty ? _uuid.v4() : task.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tasks.add(newTask);
    return newTask;
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final updated = task.copyWith(updatedAt: DateTime.now());
      _tasks[index] = updated;
      return updated;
    }
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<TaskModel>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeTaskId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _tasks.where((t) {
      if (t.id == excludeTaskId || t.status == TaskStatus.cancelled) return false;
      return t.overlapsWith(startTime, endTime);
    }).toList();
  }

  @override
  Future<List<FreeSlotModel>> getFreeSlots({
    required DateTime date,
    required int durationMinutes,
    required String workStart,
    required String workEnd,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final dayTasks = await getTasks(date: date);
    final nonCancelledTasks = dayTasks.where((t) => t.status != TaskStatus.cancelled).toList();

    final startParts = workStart.split(':');
    final endParts = workEnd.split(':');
    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(startParts[0]) ?? 9,
      int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0,
    );
    final dayEnd = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(endParts[0]) ?? 22,
      int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0,
    );

    final List<FreeSlotModel> freeSlots = [];
    DateTime pointer = dayStart;

    for (final task in nonCancelledTasks) {
      if (task.startTime.isAfter(pointer)) {
        final gapMinutes = task.startTime.difference(pointer).inMinutes;
        if (gapMinutes >= durationMinutes) {
          freeSlots.add(FreeSlotModel(
            start: pointer,
            end: task.startTime,
            durationMinutes: gapMinutes,
          ));
        }
      }
      if (task.endTime.isAfter(pointer)) {
        pointer = task.endTime;
      }
    }

    if (dayEnd.isAfter(pointer)) {
      final gapMinutes = dayEnd.difference(pointer).inMinutes;
      if (gapMinutes >= durationMinutes) {
        freeSlots.add(FreeSlotModel(
          start: pointer,
          end: dayEnd,
          durationMinutes: gapMinutes,
        ));
      }
    }

    return freeSlots;
  }

  @override
  Future<ChatMessageModel> sendUserMessage(
    String message, {
    bool isVoice = false,
    int? durationSeconds,
    required String currentLocale,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final isArabic = currentLocale == 'ar';
    final lower = message.toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Conflict simulation check (e.g. 1 PM / 13:00 / اجتماع الساعة 1)
    if (lower.contains('1 pm') ||
        lower.contains('13:00') ||
        lower.contains('الساعة 1') ||
        lower.contains('1 الظهر') ||
        lower.contains('الساعة الواحدة')) {
      final proposedStart = today.add(const Duration(hours: 13));
      final proposedEnd = today.add(const Duration(hours: 14));
      final conflicts = await checkConflicts(startTime: proposedStart, endTime: proposedEnd);
      final conflictingTask = conflicts.isNotEmpty ? conflicts.first : _tasks[1];

      final freeSlots = await getFreeSlots(
        date: today,
        durationMinutes: 45,
        workStart: '09:00',
        workEnd: '22:00',
      );

      final proposedTask = TaskModel(
        id: _uuid.v4(),
        title: isArabic ? 'اجتماع طارئ مع الفريق' : 'Team Sync Meeting',
        description: isArabic ? 'تم طلب حجز موعد عبر المساعد الذكي' : 'Requested via AI Assistant',
        startTime: proposedStart,
        endTime: proposedEnd,
        priority: TaskPriority.high,
        isVoiceCreated: isVoice,
        createdAt: now,
        updatedAt: now,
      );

      return ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: isArabic
            ? 'تنبيه: تم رصد تعارض في الوقت المطلوب مع "${conflictingTask.title}". إليك خيارات المواعيد المتاحة البديلة المقترحة:'
            : 'Warning: Conflict detected with "${conflictingTask.title}". Here are recommended alternative open windows:',
        timestamp: DateTime.now(),
        actionCard: AiActionCardModel(
          type: AiCardType.conflictAlert,
          task: proposedTask,
          conflictingTask: conflictingTask,
          freeSlots: freeSlots.take(3).toList(),
        ),
      );
    }

    // 2. Free slots query (e.g. فاضي / free / وقت / فراغ)
    if (lower.contains('فاضي') ||
        lower.contains('free') ||
        lower.contains('أوقات الفراغ') ||
        lower.contains('available') ||
        lower.contains('فراغ')) {
      final slots = await getFreeSlots(
        date: today,
        durationMinutes: 30,
        workStart: '09:00',
        workEnd: '22:00',
      );

      return ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: isArabic
            ? 'قمت بفحص جدولك لليوم ضمن ساعات العمل (09:00 - 22:00). وجدت ${slots.length} فترات زمنية شاغرة يمكنك حجزها:'
            : 'I checked your schedule today within working hours (09:00 - 22:00). Found ${slots.length} open slots ready for booking:',
        timestamp: DateTime.now(),
        actionCard: AiActionCardModel(
          type: AiCardType.freeSlots,
          freeSlots: slots,
        ),
      );
    }

    // 3. Delete task intent (e.g. احذف / delete / مسح / remove)
    if (lower.contains('احذف') ||
        lower.contains('delete') ||
        lower.contains('مسح') ||
        lower.contains('remove')) {
      final taskToDelete = _tasks.isNotEmpty ? _tasks.last : null;
      return ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: isArabic
            ? 'هل ترغب في تأكيد حذف هذه المهمة من جدولك؟'
            : 'Would you like to confirm deleting this task from your schedule?',
        timestamp: DateTime.now(),
        actionCard: AiActionCardModel(
          type: AiCardType.deleteConfirm,
          task: taskToDelete,
        ),
      );
    }

    // 4. Create task intent (e.g. ضيف / add / مراجعة / فكرني / schedule)
    if (lower.contains('ضيف') ||
        lower.contains('add') ||
        lower.contains('مراجعة') ||
        lower.contains('فكرني') ||
        lower.contains('schedule') ||
        lower.contains('create') ||
        lower.contains('review')) {
      final start = today.add(Duration(days: 1, hours: 15));
      final end = start.add(const Duration(hours: 1));

      final newTask = TaskModel(
        id: _uuid.v4(),
        title: isArabic
            ? (lower.contains('كود') ? 'مراجعة الكود البرمجي مع الفريق' : 'مراجعة المهام والأولويات')
            : (lower.contains('code') ? 'Team Code Review Session' : 'Task & Priorities Review'),
        description: isArabic
            ? 'تمت إضافة المهمة تلقائياً بواسطة المساعد الذكي الصوتي مع تذكير مسبق 30 دقيقة.'
            : 'Task added automatically by AI Voice Assistant with a 30m prior reminder.',
        startTime: start,
        endTime: end,
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        isVoiceCreated: isVoice,
        reminders: [
          ReminderModel(
            id: _uuid.v4(),
            taskId: '',
            remindAt: start.subtract(const Duration(minutes: 30)),
            offsetMinutes: 30,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await createTask(newTask);

      return ChatMessageModel(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        text: isArabic
            ? 'تمت جدولة المهمة بنجاح في جدولك! يمكنك التراجع أو تعديل التفاصيل فوراً من البطاقة أدناه.'
            : 'Task has been successfully added to your schedule! You can undo or edit details directly below.',
        timestamp: DateTime.now(),
        actionCard: AiActionCardModel(
          type: AiCardType.taskCreated,
          task: newTask,
        ),
      );
    }

    // 5. Default contextual response
    final todayTasks = await getTasks(date: today);
    return ChatMessageModel(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      text: isArabic
          ? 'لديك اليوم ${todayTasks.length} مهام مجدولة (${todayTasks.where((t) => t.isCompleted).length} مكتملة). كيف يمكنني مساعدتك أكثر؟ يمكنك قول "أنا فاضي إمتى النهاردة؟" أو "ضيف مهمة مراجعة الكود".'
          : 'You have ${todayTasks.length} tasks scheduled today (${todayTasks.where((t) => t.isCompleted).length} completed). How can I assist you? Try asking "When am I free today?" or "Add code review task".',
      timestamp: DateTime.now(),
    );
  }
}
