package dev.miniprogram.mp_only_host

internal data class MiniProgramTask(
    val taskId: Int,
    val activityClassName: String,
    val appId: String,
)

internal data class MiniProgramWindowSlot(
    val activityClassName: String,
    val existingTaskId: Int? = null,
)

internal class MiniProgramWindowLimitException : IllegalStateException(
    "All mini-program windows are in use. Close one from Recent apps before opening another.",
)

/** Uses Android's task records as ownership, including tasks restored after process death. */
internal fun selectMiniProgramWindowSlot(
    appId: String,
    activityClassNames: List<String>,
    tasks: List<MiniProgramTask>,
): MiniProgramWindowSlot {
    val windowTasks = tasks.filter { it.activityClassName in activityClassNames }
    val existing = windowTasks.firstOrNull { it.appId == appId }
    if (existing != null) {
        return MiniProgramWindowSlot(existing.activityClassName, existing.taskId)
    }
    val occupied = windowTasks.map { it.activityClassName }.toSet()
    val available = activityClassNames.firstOrNull { it !in occupied }
        ?: throw MiniProgramWindowLimitException()
    return MiniProgramWindowSlot(available)
}
