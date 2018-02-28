require 'time'
require 'csv'

Encoding.default_external = 'UTF-16LE'
Encoding.default_internal = 'UTF-8'

class NtagBackupLog
  attr_accessor :logfile, :record_num, :outfile

  SCAN_PATTERN = /(201[7-8]-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3})  <.*>  ([^ ]+) (.*$)/
  ITEMS = %i[file_id file_path file_size bof_time eof_time].map(&:freeze).freeze

  LogRecord = Struct.new(*ITEMS) do
    def duration
      return unless eof_time && bof_time
      Time.parse(eof_time) - Time.parse(bof_time)
    end
  end

  def initialize(logpath, outpath: nil)
    self.logfile = logpath
    self.outfile = outpath ? outpath : File.basename(logfile, '.log') + '.csv'
    self.record_num = 0
  end

  def make_csv_file
    use_csv_file do |csv_file|
      each_record { |record| print_csv_record csv_file, record }
    end
  end

  def each_record
    File.open(logfile, 'r') do |file|
      file.each_line do |line|
        matched = line.match(SCAN_PATTERN)
        log_record = make_log_record(matched, file)
        yield (log_record.to_a << log_record.duration)
      end
    end
  end

  private

    def make_log_record(matched, file)
      log_record = LogRecord.new
      loop do
        record_end = process_a_line(matched, log_record) if matched
        break if record_end
        line = file.gets
        break unless line
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
      self.record_num += 1
      log_record.file_id = record_num
      log_record.bof_time = matched[1]
    end

    def process_file_line(matched, log_record)
      m = matched[0].match(/<File> (.+) size = ([0-9]+\|-?[0-9]+)$/)
      log_record.file_path = m[1]
      log_record.file_size = m[2]
    end

    def process_eof_time_line(matched, log_record)
      log_record.eof_time = matched[1]
    end

    def print_csv_record(csv_file, record)
      csv_file << record
    end

    def use_csv_file
      CSV.open(
        "./#{outfile}",
        'wb+',
        headers: ITEMS + [:duration],
        write_headers: true,
        encoding: 'UTF-16LE'
      ) do |csv|
        yield csv
      end
    end
end

# NtagBackupLog.new(ARGV[0]).make_csv_file
