require './ntag_backup_log'

max_space_record = max_duration_record = [nil, nil, 0, nil, nil, 0]
NtagBackupLog.open(ARGV[0]) do |logfile|
  logfile.each_record do |record|
    max_space_record = record[2] > max_space_record[2] ? record : max_space_record
    max_duration_record = record[-1] > max_duration_record[-1] ? record : max_duration_record
  end
end
puts "max_space_record : "
p max_space_record
puts "---------"
puts "max_duration_record : "
p max_duration_record

