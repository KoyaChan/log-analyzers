require 'gnuplot'
require './ntag_backup_log.rb'


Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|

    x = []
    y = []
    y_max = 0
    max_rec = nil
    i = 0
    NtagBackupLog.open(ARGV[0], 'r') do |logfile|
      logfile.each_record do |record|
        i += 1
        # next if i < 200000
        # break if i > 280000
        next if record[1] == 0
        next if record[-1] == 0
        x << i
        throughput = (record[1].to_f * 60) / record[-1].to_f
        y << throughput
        if max_rec
          if throughput > y_max
            max_rec = record
            y_max = throughput
          end
        else
          max_rec = record
        end
      end
    end
    maxrec_file = File.basename(max_rec[0])
    puts maxrec_file
    # plot.title  "#{ARGV[0]} 200000 - 280000\\n max throughput : #{y_max}"
    plot.title  "#{ARGV[0]}\\nMAX : #{y_max} byte/min (#{max_rec[3]}) \\nfile : #{maxrec_file} : #{max_rec[1]} Bytes in #{max_rec[-1]} sec"
    plot.xlabel "file count : #{i}"
    plot.ylabel "throughput"
    plot.data << Gnuplot::DataSet.new([x, y]) do |ds|
      ds.with = 'lines'
      ds.notitle
    end
  end
end


