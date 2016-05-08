RSpec.configure do |c|
  c.filter_run_excluding :sudo => ENV.has_key?('ORACLE_HOME') && ENV['ORACLE_HOME'].start_with?('/u01')
end
