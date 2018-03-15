require 'test/unit'
require './ntag_backup_log'

class TestNtagBackupLog < Test::Unit::TestCase

  def test_file_size_0_if_size_is_0_vertical_bar_0
    nb = NtagBackupLog.new('BTKYS0313.log')
    line_str = '2018-02-18 01:59:53.997  <TID:23536><EDISON 2875:2874>  <File> E:\service1\hansya1_kiht\SH\renraku\０４年度まで, size = 0|0'
    matched = line_str.match(NtagBackupLog::SCAN_PATTERN)
    log_record = nb.send(:make_log_record, matched)
    nb.send(:process_file_line, matched, log_record)
    assert_equal 0, log_record.file_size
  end
end
