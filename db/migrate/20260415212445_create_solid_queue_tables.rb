class CreateSolidQueueTables < ActiveRecord::Migration[8.1]
  def up
    load Rails.root.join("db/queue_schema.rb")
  end

  def down
    %i[
      solid_queue_blocked_executions
      solid_queue_claimed_executions
      solid_queue_failed_executions
      solid_queue_ready_executions
      solid_queue_recurring_executions
      solid_queue_recurring_tasks
      solid_queue_scheduled_executions
      solid_queue_semaphores
      solid_queue_pauses
      solid_queue_processes
      solid_queue_jobs
    ].each { |t| drop_table t, if_exists: true }
  end
end
