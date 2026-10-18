package dev.miniprogram.mp_only_host

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class MiniProgramWindowSlotsTest {
    private val activities = listOf("host.Window0", "host.Window1", "host.Window2")

    @Test
    fun newAppsUseDifferentComponents() {
        val tasks = listOf(MiniProgramTask(11, activities[0], "booking"))
        val selected = selectMiniProgramWindowSlot("wallet", activities, tasks)
        assertEquals(activities[1], selected.activityClassName)
        assertNull(selected.existingTaskId)
    }

    @Test
    fun reopeningAnAppReusesItsTaskEvenAtCapacity() {
        val tasks = listOf(
            MiniProgramTask(11, activities[0], "booking"),
            MiniProgramTask(12, activities[1], "wallet"),
            MiniProgramTask(13, activities[2], "notes"),
        )
        val selected = selectMiniProgramWindowSlot("wallet", activities, tasks)
        assertEquals(activities[1], selected.activityClassName)
        assertEquals(12, selected.existingTaskId)
    }

    @Test
    fun closingATaskFreesOnlyItsSlot() {
        val tasks = listOf(
            MiniProgramTask(11, activities[0], "booking"),
            MiniProgramTask(13, activities[2], "notes"),
        )
        assertEquals(activities[1], selectMiniProgramWindowSlot("new", activities, tasks).activityClassName)
        assertEquals(13, selectMiniProgramWindowSlot("notes", activities, tasks).existingTaskId)
    }

    @Test
    fun fullPoolDoesNotEvictAnyLiveApp() {
        val tasks = activities.mapIndexed { index, activity -> MiniProgramTask(index, activity, "app$index") }
        assertThrows(MiniProgramWindowLimitException::class.java) {
            selectMiniProgramWindowSlot("another", activities, tasks)
        }
        assertEquals(0, selectMiniProgramWindowSlot("app0", activities, tasks).existingTaskId)
    }

    @Test
    fun unrelatedTasksDoNotOwnWindowSlots() {
        val tasks = listOf(MiniProgramTask(20, "host.MainActivity", "booking"))
        val selected = selectMiniProgramWindowSlot("booking", activities, tasks)
        assertEquals(activities[0], selected.activityClassName)
        assertNull(selected.existingTaskId)
    }

    @Test
    fun taskWithMissingAppMetadataStillReservesItsComponent() {
        val tasks = listOf(MiniProgramTask(11, activities[0], ""))
        assertEquals(activities[1], selectMiniProgramWindowSlot("booking", activities, tasks).activityClassName)
    }
}
