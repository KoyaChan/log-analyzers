require 'time'
require 'csv'

Encoding.default_external = 'UTF-16LE'
Encoding.default_internal = 'UTF-8'

class LogAnalyze
  attr_accessor :logfile, :log_record, :file_num, :csv_file, :outfile

  SCAN_PATTERN = /(201[7-8]-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3})  <.*>  ([^ ]+) (.*$)/
  ITEMS = %i[file_id file_path file_size bof_time eof_time].map(&:freeze).freeze

  LogRecord = Struct.new(*ITEMS) do
    def duration
      Time.parse(eof_time) - Time.parse(bof_time)
    end
  end

  def initialize(logpath, outpath: 'result.csv')
    self.logfile = logpath
    self.outfile = outpath
    self.file_num = 0
    self.log_record = nil
  end

  def scan_it
    use_csv do
      File.open(logfile, 'r') do |file|
        file.each_line do |line|
          matched = line.match(SCAN_PATTERN)
          if matched
            process_record if process_line(matched)
          end
        end
      end
    end
  end

  def process_line(matched)
    case matched[2]
    when %(BOF)
      self.log_record = LogRecord.new
      self.file_num += 1
      log_record.file_id = file_num
      log_record.bof_time = matched[1]
      return false
    when %(<File>)
      m = matched[0].match(/<File> (.+) size = ([0-9]+\|-?[0-9]+)$/)
      log_record.file_path = m[1]
      log_record.file_size = m[2]
      return false
    when %(BackupArchiveDetail:)
      log_record.eof_time = matched[1]
      return true
    end
    false
  end

  def process_record
    csv_file << (log_record.to_a << log_record.duration)
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

LogAnalyze.new(ARGV[0], outpath: ARGV[1]).scan_it
