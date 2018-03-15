require './ntag_backup_log'

# sorted array of arrays
class MinMaxList
  attr_accessor :list, :comp_index, :max_size

  def initialize(max_size: 30, comp_index: -1)
    self.list = []
    self.comp_index = comp_index
    self.max_size = max_size
  end

  def add_if_great(array_item)
    return unless can_add?(array_item)

    list.shift if list.size == max_size
    loc = list.size > 0 ? (list.find_index { |listed_one| listed_one[comp_index] > array_item[comp_index] } || -1) : 0
    list.insert(loc, array_item)
  end

  def each
    list.each { |array_item| yield array_item }
  end

  def reverse
    list.reverse
  end

  private

    def can_add?(array_item)
      return true if list.size < max_size

      greater_than_min?(array_item)
    end

    def greater_than_min?(array_item)
      array_item[comp_index] > list[0][comp_index]
    end

end

class TopThirty
  MAX_ITEMS = 30
  attr_accessor :top_durations, :top_beforebofs, :top_filesizes, :logfile

  def initialize(logfile)
    self.top_durations = MinMaxList.new(max_size: MAX_ITEMS, comp_index: -1)
    self.top_beforebofs = MinMaxList.new(max_size: MAX_ITEMS, comp_index: 2)
    self.top_filesizes = MinMaxList.new(max_size: MAX_ITEMS, comp_index: 1)
    self.logfile = logfile
  end

  def use_logfile
    NtagBackupLog.open(logfile) do |f|
      yield f
    end
  end

  def list_top_records
    use_logfile do |log|
      log.each_record do |record|
        top_durations.add_if_great(record)
        top_beforebofs.add_if_great(record)
        top_filesizes.add_if_great(record)
      end
    end
  end
  
  def print_header
    puts '<table border="1" cellspacing="0" cellpadding="5" bordercolor="#333333"><thead><tr>'
    puts '<th>BOF前の空き時間</th><th>BOF時刻</th><th>転送時間(秒)</th><th>ファイルサイズ(Byte)</th><th width="500">スループット(Byte/分)</th><th>ファイル名</th>'
    puts '</tr></thead>'
  end
  
  def print_footer
    puts '</table>'
  end
  
  def print_data(top_records)
    total_send = 0
    total_size = 0
    top_records.each do |record|
      total_send += record[-1].to_f
      total_size += record[1].to_f
      throughput = record[-1].to_f > 0 ? (record[1].to_f * 60) / record[-1].to_f : 'N/A'
      puts '<tr>'
      puts "<td> #{record[2]}</td>"
      puts "<td> #{record[3]}</td>"
      puts "<td> #{record[-1]}</td>"
      puts "<td> #{record[1]}</td>"
      puts "<td> #{throughput}</td>"
      puts "<td> #{record[0]}</td>"
      puts '</tr>'
    end
    puts "<tr><td></td><td></td><td>#{total_send}</td><td>#{total_size}</td><td></td></tr>"
  end

  def print_htm
    puts '<html><body>'
    puts "<h1>#{logfile}</h1>"
    puts '<h2>転送時間 top 30</h2>'
    list_top_records
    print_header
    print_data(top_durations.reverse)
    print_footer
    puts '<h2>ファイルサイズ top 30</h2>'
    print_header
    print_data(top_filesizes.reverse)
    print_footer
    puts '<h2>BOF前の空き時間 top 30</h2>'
    print_header
    print_data(top_beforebofs.reverse)
    print_footer
    puts "</body></html>"
  end
end

TopThirty.new(ARGV[0]).print_htm
