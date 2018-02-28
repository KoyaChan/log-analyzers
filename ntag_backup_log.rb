require 'time'
require 'csv'

Encoding.default_external = 'UTF-16LE'
Encoding.default_internal = 'UTF-8'

class NtagBackupLog
  attr_accessor :logfile, :log_record, :file_num, :csv_file, :outfile, :max_duration

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
    self.file_num = 0
    self.log_record = nil
  end

  def make_csv
    use_csv do
      File.open(logfile, 'r') do |file|
        file.each_line do |line|
          matched = line.match(SCAN_PATTERN)
          if matched
            print_to_csv if make_record(matched, file)
          end
        end
      end
    end
  end

  private

    def make_record(matched, file)
      self.log_record = LogRecord.new
      loop do
        record_end = process_a_line(matched) if matched
        break if record_end
        line = file.gets
        break unless line
        matched = line.match(SCAN_PATTERN)
      end
      log_record
    end

    def process_a_line(matched)
      case matched[2]
      when %(BOF)
        process_bof_line matched
      when %(<File>)
        process_file_line matched
      when %(BackupArchiveDetail:)
        process_eof_time_line matched
        return true
      end
      false
    end

    def process_bof_line(matched)
      self.file_num += 1
      log_record.file_id = file_num
      log_record.bof_time = matched[1]
    end

    def process_file_line(matched)
      m = matched[0].match(/<File> (.+) size = ([0-9]+\|-?[0-9]+)$/)
      log_record.file_path = m[1]
      log_record.file_size = m[2]
    end

    def process_eof_time_line(matched)
      log_record.eof_time = matched[1]
    end

    def print_to_csv
      duration = log_record.duration
      csv_file << (log_record.to_a << duration) # if duration > 0
    end

    def use_csv
      CSV.open(
        "./#{outfile}",
        'wb+',
        headers: ITEMS + [:duration],
        write_headers: true,
        encoding: 'UTF-16LE'
      ) do |csv|
        self.csv_file = csv
        yield
      end
    end
end

NtagBackupLog.new(ARGV[0]).make_csv
