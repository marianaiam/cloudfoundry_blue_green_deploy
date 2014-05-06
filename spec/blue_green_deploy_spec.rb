require 'spec_helper'
require_relative 'cloud_foundry_fake'

describe BlueGreenDeploy do
  let(:cf_manifest) { YAML.load_file('spec/manifest.yml') }
  let(:worker_app_names) { ['the-web-app-worker'] }
  let(:deploy_config) { BlueGreenDeployConfig.new(cf_manifest, app_name, worker_app_names, target_color) }
  let(:domain) { 'cfapps.io' }
  let(:hot_url) { 'the-web-url' }
  let(:app_name) { 'the-web-app' }

  describe '#make_it_so' do
    context 'when blue/green is specified' do
      let(:worker_apps) { worker_app_names }
      let(:target_color) { 'green' }
      let(:current_hot_app) { 'blue' }
      subject { BlueGreenDeploy.make_it_so(app_name, worker_apps, deploy_config) }
      before do
        allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
        CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
        CloudFoundryFake.init_app_list_with_workers_for(app_name)
      end

      it 'instructs Cloud Foundry to deploy the specified web app; ' +
         'THEN, deploys each of the specified worker apps, stopping their counterparts; ' +
         'and THEN, makes the specified web app "hot" ' +
         '(mapping the "hot" route to it and unmapping that "hot" route from it`s counterpart)' do
        green_or_blue = BlueGreenDeployConfig.toggle_color(target_color)
        old_worker_app_full_name = "#{worker_apps.first}-#{green_or_blue}"
        new_worker_app_full_name = "#{worker_apps.first}-#{target_color}"
        new_web_app_full_name = "#{app_name}-#{target_color}"
        old_web_app_full_name = "#{app_name}-#{green_or_blue}"

        expect(CloudFoundryFake).to receive(:push).with(new_web_app_full_name).ordered.and_call_original
        expect(CloudFoundryFake).to receive(:push).with(new_worker_app_full_name).ordered.and_call_original
        expect(CloudFoundryFake).to receive(:stop).with(old_worker_app_full_name).ordered.and_call_original
        expect(CloudFoundryFake).to receive(:map_route).with(new_web_app_full_name, domain, hot_url).ordered.and_call_original
        expect(CloudFoundryFake).to receive(:unmap_route).with(old_web_app_full_name, domain, hot_url).ordered.and_call_original

        subject
      end

    end

    context 'when blue/green is omitted and there is already a hot app' do
      let(:target_color) { nil }
      let(:worker_apps) { worker_app_names }
      subject { BlueGreenDeploy.make_it_so(app_name, worker_apps, deploy_config) }
      before do
        allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
        CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
        CloudFoundryFake.init_app_list_with_workers_for(app_name)
      end

      context 'green is the current hot app' do
        let(:current_hot_app) { 'green' }

        it 'makes blue the current hot app' do
          subject
          expect(CloudFoundryFake.find_route(hot_url).app).to eq "#{app_name}-blue"
        end
      end

      context 'blue is the current hot app' do
        let(:current_hot_app) { 'blue' }

        it 'makes green the current hot app' do
          subject
          expect(CloudFoundryFake.find_route(hot_url).app).to eq "#{app_name}-green"
        end
      end

    end
  end

  describe '#ready_for_takeoff' do
    subject { BlueGreenDeploy.ready_for_takeoff(hot_app_name, deploy_config) }
    let(:target_color) { 'green' }
    let(:hot_app_name) { "#{app_name}-#{current_hot_app}" }
    let(:worker_apps) { CloudFoundryFake.apps }
    before do
      allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
      CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
      CloudFoundryFake.init_app_list_with_workers_for(app_name)
    end

    context 'the target color is the cold app color.' do
      let(:current_hot_app) { 'blue' }

      it 'does not raise an error: "It`s kosh!"' do
        expect{ subject }.to_not raise_error
      end

      context 'but, one or more of the corresponding worker apps is already hot' do
        before { CloudFoundryFake.replace_app(App.new(name: "#{app_name}-worker-#{target_color}", state: 'started')) }

        it 'raises an InvalidWorkerStateError' do
          expect{ subject }.to raise_error(InvalidWorkerStateError)
        end
      end
    end

    context 'the target color matches what`s already hot' do
      let(:current_hot_app) { 'green' }
      it 'raises an InvalidRouteStateError' do
        expect{ subject }.to raise_error(InvalidRouteStateError)
      end
    end

    context 'when blue/green is omitted' do
      let(:target_color) { nil }

      context 'there is no current hot app' do
        let(:current_hot_app) { '' }
        let(:hot_app_name) { nil }
        before { CloudFoundryFake.remove_route(hot_url) }

        it 'raises an InvalidRouteStateError' do
          expect{ subject }.to raise_error(InvalidRouteStateError)
        end
      end
    end
  end

  describe '#get_hot_app' do
    subject { BlueGreenDeploy.get_hot_app(hot_url) }
    let(:current_hot_color) { 'green' }
    let(:hot_app) { "#{app_name}-#{current_hot_color}" }

    before do
      allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
      CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_color)
    end

    it 'returns the app mapped to that Host URL' do
      expect(subject).to eq hot_app
    end

    context 'when there is no app mapped to the hot url' do
      before { CloudFoundryFake.remove_route(hot_url) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end


  describe '#make_hot' do
    let(:target_color) { 'blue' }
    let(:current_hot_app) { 'green' }
    subject { BlueGreenDeploy.make_hot(app_name, deploy_config) }

    before do
      allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
      CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
    end

    context 'when there is no current hot app' do
      before do
        CloudFoundryFake.remove_route(hot_url)
      end

      it 'the target_color is mapped to the hot_url' do
        subject
        expect(BlueGreenDeploy.get_hot_app(hot_url)).to eq "#{app_name}-#{target_color}"
      end
    end

    context 'when there IS a hot URL route, but it is not mapped to any app' do
      before do
        CloudFoundryFake.remove_route(hot_url)
        CloudFoundryFake.add_route(Route.new(hot_url, domain, nil))
      end

      it 'the target_color is mapped to the hot_url' do
        subject
        expect(BlueGreenDeploy.get_hot_app(hot_url)).to eq "#{app_name}-#{target_color}"
      end
    end

    context 'when the hot url IS mapped to an app, already' do
      it 'the app that was mapped to the hot_url is no longer mapped to hot_url' do
        subject
        expect(BlueGreenDeploy.get_hot_app(hot_url)).to_not eq "#{app_name}-#{current_hot_app}"
      end

      it 'the target_color is mapped to the hot_url' do
        subject
        expect(BlueGreenDeploy.get_hot_app(hot_url)).to eq "#{app_name}-#{target_color}"
      end
    end
  end
end
