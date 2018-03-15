require 'time'
require 'csv'

Encoding.default_external = 'UTF-16LE'
Encoding.default_internal = 'UTF-8'

# NtagBackupLog
# reads in a client agent job log, and make a record with a pattern of lines
# which repeats for each file backed up, like the following:
# 2018-02-17 02:31:25.577 BOF
#    ...
# with the above lines, make a record below:
#   ...
# 
# usage : 
# NtagBackupLog.open('<logfile path>') do |file|
#   file.each_record do |record|
#   << do something with the record >>
#   end
# end
#
# Instance method make_csv_file can be used to print a csv file with the records
# file = NtagBackupLog.new('<logfile path>')
# file.make_csv_file('<csv file name>')
# file.close
#
# when <csv file name> isn't specified, default csv file name is 
# <base name of log file>.csv
#
class NtagBackupLog
  # :prev_eof_time is the time from the eof_time of previous file, and bof_time of
  # current file.
  attr_accessor :logfile, :prev_eof_time
  
  SCAN_PATTERN = /(201[7-8]-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3})  <.*>  ([^ ]+) (.*$)/

  # items to be included in the record
  ITEMS = %i[file_path file_size before_bof bof_time eof_time].map(&:freeze).freeze

  # structure to set the item values for the record temporarily
  LogRecord = Struct.new(*ITEMS) do
    def duration  # time duration from bof_time to eof_time
      return unless eof_time && bof_time
      Time.parse(eof_time) - Time.parse(bof_time)
    end
  end

  def self.open(*args)
    f = File.open(*args)
    begin
      ntag_backup_log = new(f)
    rescue Exception
      f.close
      raise
    end

    if block_given?
      begin
        yield ntag_backup_log
      ensure
        ntag_backup_log.close
      end
    else
      ntag_backup_log
    end
  end

  def initialize(logpath)
    self.logfile = logpath.is_a?(String) ? File.new(logpath) : logpath
  end

  def make_csv_file(outpath = nil)
    file = outpath ? outpath : File.basename(logfile, '.log') + '.csv'
    create_csv_file(file) do |csv_file|
      each_record { |record| print_csv_record csv_file, record }
    end
    self
  end

  def each_record
    while (record = next_record)
      yield record
    end
    self
  end

  def next_record
    logfile.each_line do |line|
      matched = line.match(SCAN_PATTERN)
      if matched
        log_record = make_log_record(matched)
        return log_record ? (log_record.to_a << log_record.duration) : nil
      end
    end
    nil
  end

  def close
    logfile.close
  end

  private

    def make_log_record(matched)
      log_record = LogRecord.new
      loop do
        record_end = process_a_line(matched, log_record) if matched
        break if record_end
        line = logfile.gets
        return nil unless line
        matched = line.match(SCAN_PATTERN)
      end
      log_record
    end

    def process_a_line(matched, log_record)
      case matched[2]
      when %(BOF)
        process_bof_line matched, log_record
      when %(<File>)
        process_file_line matched, log_record
      when %(BackupArchiveDetail:)
        process_eof_time_line matched, log_record
        return true
      end
      false
    end

    def process_bof_line(matched, log_record)
      log_record.bof_time = matched[1]
      log_record.before_bof =
        if prev_eof_time
          Time.parse(log_record.bof_time) - Time.parse(prev_eof_time)
        else
          0
        end
    end

    def process_file_line(matched, log_record)
      m = matched[0].match(/<File> (.+), size = ([0-9]*)\|?(-?)([0-9]+)$/)
      log_record.file_path = m[1]
      size_low = m[3] ? '100000000'.to_i(16) - m[4].to_i : m[4].to_i
      log_record.file_size = make_filesize(m[2].to_i, size_low)
    end

    # "<num1>|<num2>" is recorded in the log. <num1> is nFileSizeHigh,
    # <num2> is nFileSizeLow in WIN32_FIND_DATA structure
    def make_filesize(size_high, size_low)
      max_dword = "ffffffff".to_i(16) + 1
      size_high * max_dword + size_low
    end

    def process_eof_time_line(matched, log_record)
      log_record.eof_time = matched[1]
      self.prev_eof_time = log_record.eof_time
    end

    def print_csv_record(csv_file, record)
      csv_file << record
    end

    def create_csv_file(csv_file)
      CSV.open(
        "./#{csv_file}",
        'wb+',
        headers: ITEMS + [:duration],
        write_headers: true,
        encoding: 'UTF-16LE'
      ) do |csv|
        yield csv
      end
    end
end

# NtagBackupLog.new(ARGV[0]).make_csv_file.close
# NtagBackupLog.open(ARGV[0], &:make_csv_file)

# NtagBackupLog.open(ARGV[0]) do |logfile|
#   p logfile.next_record
# end
