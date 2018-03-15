require './ntag_backup_log'

NtagBackupLog.open(ARGV[0], &:make_csv_file)
