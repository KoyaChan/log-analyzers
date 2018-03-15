require 'test/unit'
require './ntag_backup_log'

class TestNtagBackupLog < Test::Unit::TestCase
  attr_accessor :nb

  def setup
    self.nb = NtagBackupLog.new('BTEST0313.log')
  end

  def test_file_size_0_if_size_is_0_vertical_bar_0
    line_str = '2018-02-18 01:59:53.997  <TID:23536><EDISON 2875:2874>  <File> E:\service1\hansya1_kiht\SH\renraku\０４年度まで, size = 0|0'
    matched = line_str.match(NtagBackupLog::SCAN_PATTERN)
    log_record = nb.send(:make_log_record, matched)
    nb.send(:process_file_line, matched, log_record)
    assert_equal 0, log_record.file_size
  end

  def test_file_size_is_size_low_if_size_high_is_0
    line_str = '2018-02-11 14:44:58.363  <TID:9584><TKYSV06 752:751>  <File> D:\Appls\CA\ARCserve Backup Client Agent for Windows\VmwareVcbMountDir\TKYSV84\TKYSV82.nvram, size = 0|8684'
    matched = line_str.match(NtagBackupLog::SCAN_PATTERN)
    log_record = nb.send(:make_log_record, log_record)
    nb.send(:process_file_line, matched, log_record)
    assert_equal 8684, log_record.file_size
  end


end
