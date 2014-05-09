require 'spec_helper'

describe BlueGreenDeployConfig do
  let(:cf_manifest) { YAML.load_file('spec/manifest.yml') }
  let(:web_app_name) { 'the-web-app' }
  let(:web_url_name) { 'the-web-url' }
  let(:worker_app_names) { ['the-web-app-worker', 'hard-worker'] }
  let(:with_shutter) { false }
  let(:target_color) { nil }
  let(:deploy_config) do
    config = BlueGreenDeployConfig.new(cf_manifest, web_app_name, worker_app_names, with_shutter)
    config.target_color = target_color
    config
  end

  describe '#initialize' do
    subject { deploy_config }
    context 'given a parsed conforming manifest.yml' do
      it 'calculates the "Hot URL"' do
        expect(subject.hot_url).to eq "#{web_url_name}"
      end

      it 'determines the "domain" (i.e the Cloud Foundry domain)' do
        expect(subject.domain).to eq 'cfapps.io'
      end

      context 'user requested "shutter treatment"' do
        let(:with_shutter) { true }
        it 'indicates "use shutter"' do
          expect(subject.with_shutter).to eq true
        end
      end
    end

    describe '(vetting parameters against the contents of the manifest)' do
      context 'given the "web_app_name" parameter does not match any of the applications defined in the manifest.yml' do
        let(:web_app_name) { 'the-web-pap' }
        it 'raises an InvalidManifestError' do
          expect{subject}.to raise_error InvalidManifestError
        end
      end

      context 'given one of the instances of a worker application is not defined in the manifest' do
        let(:worker_app_names) { ['the-web-app-wroker', 'hard-worker'] }
        it 'raises an InvalidManifestError' do
          expect{subject}.to raise_error InvalidManifestError
        end
      end
    end

    context 'given the "web_app_name" matches, but the host name is not defined' do
      let(:cf_manifest) { {"applications"=>[{"name"=>"the-web-app-blue"}]} }
      let(:worker_app_names) { [] }
      it 'raises an InvalidManifestError' do
        expect{subject}.to raise_error InvalidManifestError
      end
    end

    context 'given the "web_app_name" matches, but the domain is not defined' do
      let(:cf_manifest) { {"applications"=>[{"name"=>"the-web-app-blue", "host"=> "#{web_url_name}"}]} }
      let(:worker_app_names) { [] }
      it 'raises an InvalidManifestError' do
        expect{subject}.to raise_error InvalidManifestError
      end
    end

  end

  context 'the target color was calculated by Blue Green deploy' do
    let(:target_color) { 'green' }

    describe '.target_web_app_name' do
      subject { deploy_config.target_web_app_name }
      it 'calculates the "target" web app name' do
        expect(subject).to eq "the-web-app-#{target_color}"
      end
    end

    describe '.target_worker_app_names' do
      subject { deploy_config.target_worker_app_names }

      it 'calculates the "target" worker app names' do
        expect(subject[0]).to eq 'the-web-app-worker-green'
        expect(subject[1]).to eq 'hard-worker-green'
      end
    end
  end

  describe '.shutter_app_name' do
    subject { deploy_config.shutter_app_name }
    it 'provides the CF app name for the Shutter app.' do
      expect(subject).to eq "#{web_app_name}-shutter"
    end
  end


  describe '#strip_color' do
    let(:app_name_with_color) { 'some-app-name-here-yay-blue' }
    subject { BlueGreenDeployConfig.strip_color(app_name_with_color) }

    it 'returns just the name of the app' do
      expect(subject).to eq 'some-app-name-here-yay'
    end

  end

  describe '#toggle_app_color' do
    let(:app_name) { 'app_name' }
    let(:target_app_name) { "#{app_name}-#{starting_color}" }
    subject { BlueGreenDeployConfig.toggle_app_color(target_app_name) }

    context 'where named app is the green instance' do
      let(:starting_color) { 'green' }
      it 'provides the blue app name' do
        expect(subject).to eq "#{app_name}-blue"
      end
    end
  end

  describe '.is_in_target?' do
    let(:target_color) { 'green' }
    let(:app_name) { "app_name-#{app_color}" }
    subject { deploy_config.is_in_target?(app_name) }

    context 'when the specified app IS the name of the target app' do
      let(:app_color) { target_color }
      it 'returns true' do
        expect(subject).to be true
      end
    end
    context 'when the specified app is NOT the name of the target app' do
      let(:app_color) { BlueGreenDeployConfig.toggle_color(target_color) }
      it 'returns false' do
        expect(subject).to be false
      end
    end
  end
end
