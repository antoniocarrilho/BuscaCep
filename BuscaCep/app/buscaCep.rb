require_relative 'buscaCep_request'
require_relative '../utils/mechanize_utils'
require 'step_machine'
require 'pry'
include  StepMachine
include Utils::MechanizeUtils
include BuscaCepRequests

init_mechanize

ZIP_CODE_TYPE = {
    '1' => 'Esta cidade possui CEP unico',
    '2' => 'Esta cidade possui CEP por logradouro'
}

STATES = {
    'AC' => 'Acre',
    'AL' => 'Alagoas',
    'AP' => 'Amapá',
    'AM' => 'Amazonas',
    'BA' => 'Bahia',
    'CE' => 'Ceará',
    'DF' => 'Distrito Federal',
    'ES' => 'Espírito Santo',
    'GO' => 'Goías',
    'MA' => 'Maranhão',
    'MT' => 'Mato Grosso',
    'MS' => 'Mato Grosso o Sul',
    'MG' => 'Minas Gerais',
    'PA' => 'Pará',
    'PB' => 'Paraíba',
    'PR' => 'Paraná',
    'PE' => 'Pernambuco',
    'PI' => 'Piauí',
    'RJ' => 'Rio de Janeiro',
    'RN' => 'Rio Grande do Norte',
    'RS' => 'Rio Grande do Sul',
    'RO' => 'Rondônia',
    'RR' => 'Roráima',
    'SC' => 'Santa Catarina',
    'SP' => 'São Paulo',
    'SE' => 'Sergipe',
    'TO' => 'Tocantins',
}

step(:insert_zip_code) do
    puts "====INSERT CEP===="
    print 'CEP:'
    @zip_code = gets.chomp.to_s
end.validate do |step|
    @zip_code.insert(5,'-') if !@zip_code.include?('-')
    step.errors << 'The zip code must contain 8 digits' if @zip_code.length != 9
end


step(:zip_code_search) do
    post search_cep_request
end.validate do |step|
    page = JSON.parse(step.result.body)
    step.errors << "CEP #{@zip_code} NÃO ENCONTRAO" if !page['dados'].first['logradouroDNEC'].match(/O CEP [0-9]{5}-[0-9]{3} NAO FOI ENCONTRADO/).nil?
    unless page['dados'].first['logradouroDNEC'].match(/CEP [0-9]{5}-[0-9]{3} DESMEMBRADO/).nil?
        @zip_code_data = page['dados'][1]
    else
        @zip_code_data = page['dados'][0]
    end

    @place = @zip_code_data['logradouroDNEC'].include?('até') ? @zip_code_data['logradouroDNEC'].gsub(/-.até.?*/,'') : @zip_code_data['logradouroDNEC']

end.success do |step|
    @city          = @zip_code_data['localidade']
    @zip_code_type = @zip_code_data['tipoCep']
    @neighborhood  = @zip_code_data['bairro']
    @state         = @zip_code_data['uf']
    if @city.include?(' ')
        @city_formated = @city.delete(' ')
    else
        @city_formated = @city
    end
end

step(:search_city_weather_json) do
    post search_city_weather_request
end.validate do |step|
    page = JSON.parse(step.result.body)
    step.errors << 'Resultado não encontrado' if page.first['response']['success'].eql?('true')
end.success do |step|
    @city_code = page.first['response']['data'].first['idcity']
end

step(:city_weather_condition_page) do
    post city_weather_condition_page_request
end.success do |step|
    @current_temperature = step.result.search('span[class="-bold -gray-dark-2 -font-55 _margin-l-20 _center"]').text.delete("\n")
    @current_weather     = step.result.search('span[class="col"]').text
    @thermal_sensation   = step.result.search('span[class=""]').text.downcase.delete("\n").gsub!(/[a-sçã-]/, '').delete(' ')
end

step(:result) do
    puts "=====RESULT====="
    puts "\nCidade: #{@city}"
    puts "Estado: #{STATES[@state]}"
    if @zip_code_type.eql?('2')
        puts "Logradouro: #{@place}"
        puts "Bairro: #{@neighborhood}"
    end

    puts "Observação: #{ZIP_CODE_TYPE[@zip_code_type]}"
    puts "\n====INFORMAÇÃO METEREOLÓGICA===="
    puts "\n#{@current_weather}"
    puts "Temperatura de #{@current_temperature} graus Celsius"
    puts "Sensação termica de #{@thermal_sensation} graus Celsius"
    puts "\n================"
end

on_step_failure do |f|
    unless f.step.errors.empty?
        puts "======ERROR======"
        puts "The following error occurred during zip code search: #{f.step.errors.join}"
    end
end

run_steps

