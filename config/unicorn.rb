worker_processes Integer(ENV["WEB_CONCURRENCY"] || 4)
timeout 8
preload_app true

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
  Rails.logger.info('before_fork: Disconnected from Database')
    
  defined?($redis) and $redis.quit
  Rails.logger.info('before_fork: Disconnected from Redis')
end 

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
  Rails.logger.info('after_fork: Connected to Database')
    
  Redis.connect_to_redis!
  Rails.logger.info('after_fork: Connected to Redis')
end
