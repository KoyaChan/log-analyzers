require './ntag_backup_log'

total_before_bof = 0
total_duration = 0
NtagBackupLog.open(ARGV[0]) do |logfile|
  logfile.each_record do |record|
    total_before_bof += record[2]
    total_duration += record[-1]
  end
end

puts "total_before_bof : #{total_before_bof}"
puts "total_duration : #{total_duration}"
