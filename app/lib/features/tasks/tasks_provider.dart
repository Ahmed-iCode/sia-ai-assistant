import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/task_model.dart';
import '../../core/services/task_repository.dart';
import '../../core/services/rest_task_repository.dart';
import '../auth/auth_provider.dart';

enum TaskViewMode { today, thisWeek, timeline, calendar }

enum TaskStatusFilter { all, pending, inProgress, completed }

enum TaskPriorityFilter { all, urgent, high, medium, low }

class TasksFilterState {
  final TaskViewMode viewMode;
  final TaskStatusFilter statusFilter;
  final TaskPriorityFilter priorityFilter;
  final String searchQuery;
  final DateTime selectedDate;

  const TasksFilterState({
    this.viewMode = TaskViewMode.today,
    this.statusFilter = TaskStatusFilter.all,
    this.priorityFilter = TaskPriorityFilter.all,
    this.searchQuery = '',
    required this.selectedDate,
  });

  TasksFilterState copyWith({
    TaskViewMode? viewMode,
    TaskStatusFilter? statusFilter,
    TaskPriorityFilter? priorityFilter,
    String? searchQuery,
    DateTime? selectedDate,
  }) {
    return TasksFilterState(
      viewMode: viewMode ?? this.viewMode,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class TasksFilterNotifier extends Notifier<TasksFilterState> {
  @override
  TasksFilterState build() {
    final now = DateTime.now();
    return TasksFilterState(selectedDate: DateTime(now.year, now.month, now.day));
  }

  void setViewMode(TaskViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setStatusFilter(TaskStatusFilter status) {
    state = state.copyWith(statusFilter: status);
  }

  void setPriorityFilter(TaskPriorityFilter priority) {
    state = state.copyWith(priorityFilter: priority);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }
}

final tasksFilterProvider = NotifierProvider<TasksFilterNotifier, TasksFilterState>(
  TasksFilterNotifier.new,
);

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return ref.watch(restTaskRepositoryProvider);
});

class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    final authState = await ref.watch(authProvider.future);
    if (!authState.isAuthenticated) {
      return const [];
    }
    final repo = ref.watch(taskRepositoryProvider);
    return await repo.getTasks();
  }

  Future<void> refresh() async {
    final authState = ref.read(authProvider).value;
    if (authState == null || !authState.isAuthenticated) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(taskRepositoryProvider);
      return await repo.getTasks();
    });
  }

  Future<void> toggleTaskStatus(String id) async {
    final currentTasks = state.value ?? [];
    final index = currentTasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = currentTasks[index];
    final newStatus = task.isCompleted ? TaskStatus.pending : TaskStatus.completed;
    final updatedTask = task.copyWith(status: newStatus);

    // Optimistic UI update
    final updatedList = List<TaskModel>.from(currentTasks);
    updatedList[index] = updatedTask;
    state = AsyncValue.data(updatedList);

    final repo = ref.read(taskRepositoryProvider);
    await repo.updateTask(updatedTask);
  }

  Future<TaskModel> createTask(TaskModel task, {bool force = false}) async {
    final repo = ref.read(taskRepositoryProvider);
    final created = repo is RestTaskRepository
        ? await repo.createTask(task, force: force)
        : await repo.createTask(task);
    final currentTasks = state.value ?? [];
    state = AsyncValue.data([...currentTasks, created]);
    return created;
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    final repo = ref.read(taskRepositoryProvider);
    final updated = await repo.updateTask(task);
    final currentTasks = state.value ?? [];
    final index = currentTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final updatedList = List<TaskModel>.from(currentTasks);
      updatedList[index] = updated;
      state = AsyncValue.data(updatedList);
    }
    return updated;
  }

  Future<void> deleteTask(String id) async {
    final currentTasks = state.value ?? [];
    state = AsyncValue.data(currentTasks.where((t) => t.id != id).toList());
    final repo = ref.read(taskRepositoryProvider);
    await repo.deleteTask(id);
  }
}

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<TaskModel>>(
  TasksNotifier.new,
);

/// Filtered tasks selector
final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final filter = ref.watch(tasksFilterProvider);

  final tasks = tasksAsync.value ?? [];
  return tasks.where((t) {
    // 1. Search Query
    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      final titleMatch = t.title.toLowerCase().contains(q);
      final descMatch = t.description?.toLowerCase().contains(q) ?? false;
      if (!titleMatch && !descMatch) return false;
    }

    // 2. View Mode (Today vs This Week vs Timeline vs Calendar)
    final taskDate = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
    if (filter.viewMode == TaskViewMode.today) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!taskDate.isAtSameMomentAs(today)) return false;
    } else if (filter.viewMode == TaskViewMode.thisWeek) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      if (t.startTime.isBefore(startOfWeek) || t.startTime.isAfter(endOfWeek)) {
        return false;
      }
    } else if (filter.viewMode == TaskViewMode.calendar) {
      // In Calendar mode, all tasks matching search/status/priority are preserved
      // so the interactive calendar can plot markers across the entire month.
    }

    // 3. Status filter
    if (filter.statusFilter != TaskStatusFilter.all) {
      if (filter.statusFilter == TaskStatusFilter.pending && t.status != TaskStatus.pending) return false;
      if (filter.statusFilter == TaskStatusFilter.inProgress && t.status != TaskStatus.inProgress) return false;
      if (filter.statusFilter == TaskStatusFilter.completed && t.status != TaskStatus.completed) return false;
    }

    // 4. Priority filter
    if (filter.priorityFilter != TaskPriorityFilter.all) {
      if (filter.priorityFilter == TaskPriorityFilter.urgent && t.priority != TaskPriority.urgent) return false;
      if (filter.priorityFilter == TaskPriorityFilter.high && t.priority != TaskPriority.high) return false;
      if (filter.priorityFilter == TaskPriorityFilter.medium && t.priority != TaskPriority.medium) return false;
      if (filter.priorityFilter == TaskPriorityFilter.low && t.priority != TaskPriority.low) return false;
    }

    return true;
  }).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
});

/// Convenience selector to get all tasks on a specific calendar day
final tasksForDayProvider = Provider.family<List<TaskModel>, DateTime>((ref, day) {
  final tasks = ref.watch(filteredTasksProvider);
  final target = DateTime(day.year, day.month, day.day);
  return tasks.where((t) {
    final taskDay = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
    return taskDay.isAtSameMomentAs(target);
  }).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
});
