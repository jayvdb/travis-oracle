
describe 'download.sh' do
  context 'when ORACLE_FILE and ORACLE_ZIP_DIR are defined', :if => ENV.has_key?('ORACLE_FILE') && ENV.has_key?('ORACLE_ZIP_DIR') do
    let(:zip) { ENV['ORACLE_ZIP_DIR'] + '/' + File.basename(ENV['ORACLE_FILE']) }

    it 'downloads from Oracle into specified directory' do
      expect(File).to exist(zip)
    end
  end

  context 'when ORACLE_FILE is defined', :if => ENV.has_key?('ORACLE_FILE') && ! ENV.has_key?('ORACLE_ZIP_DIR') do
    it 'downloads from Oracle into cwd' do
      expect(File).to exist(File.basename(ENV['ORACLE_FILE']))
    end
  end
end
