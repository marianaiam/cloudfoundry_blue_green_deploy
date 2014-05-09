require 'spec_helper'
require_relative 'cloud_foundry_fake'

module CloudfoundryBlueGreenDeploy
  describe BlueGreenDeploy do
    let(:cf_manifest) { YAML.load_file('spec/manifest.yml') }
    let(:worker_app_names) { ['the-web-app-worker'] }
    let(:deploy_config) { BlueGreenDeployConfig.new(cf_manifest, app_name, worker_app_names, with_shutter) }
    let(:domain) { 'cfapps.io' }
    let(:hot_url) { 'the-web-url' }
    let(:app_name) { 'the-web-app' }
    let(:with_shutter) { nil }

    describe '#make_it_so' do
      context 'steady-state deploy (not first deploy, already a hot app)' do
        let(:worker_apps) { worker_app_names }
        let(:target_color) { 'green' }
        let(:current_hot_app) { 'blue' }

        subject { BlueGreenDeploy.make_it_so(app_name, worker_apps, deploy_config) }

        before do
          allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
          CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
          CloudFoundryFake.init_app_list_with_workers_for(app_name)
        end

        context 'AND deploy does not require shutter' do
          let(:with_shutter) { false }
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

        context 'AND deploy requires shutter' do
          let(:with_shutter) { true }
          it 'instructs Cloud Foundry to deploy the specified web app; ' +
            'THEN, deploys each of the specified worker apps, stopping their counterparts; ' +
            'and THEN, makes the specified web app "hot" ' +
            '(mapping the "hot" route to it and unmapping that "hot" route from it`s counterpart)' do
              green_or_blue = BlueGreenDeployConfig.toggle_color(target_color)
              shutter_app_name = deploy_config.shutter_app_name
              old_worker_app_full_name = "#{worker_apps.first}-#{green_or_blue}"
              new_worker_app_full_name = "#{worker_apps.first}-#{target_color}"
              new_web_app_full_name = "#{app_name}-#{target_color}"
              old_web_app_full_name = "#{app_name}-#{green_or_blue}"

              expect(CloudFoundryFake).to receive(:push).with(shutter_app_name).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:map_route).with(shutter_app_name, domain, hot_url).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:unmap_route).with(old_web_app_full_name, domain, hot_url).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:push).with(new_web_app_full_name).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:push).with(new_worker_app_full_name).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:stop).with(old_worker_app_full_name).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:map_route).with(new_web_app_full_name, domain, hot_url).ordered.and_call_original
              expect(CloudFoundryFake).to receive(:unmap_route).with(shutter_app_name, domain, hot_url).ordered.and_call_original

              subject
            end

        end
      end

      context 'it is a first deploy' do
        let(:target_color) { nil }
        let(:worker_apps) { worker_app_names }
        subject { BlueGreenDeploy.make_it_so(app_name, worker_apps, deploy_config) }
        before do
          allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
        end

        context 'there is no hot app' do
          let(:current_hot_app) { nil }
          before { CloudFoundryFake.clear_route_table }

          context 'there are no hot worker apps' do
            let(:worker_app_names) { [] }
            before { CloudFoundryFake.clear_app_list }
            it 'deploys "blue" instances' do
              subject
              hot_web_app = CloudFoundryFake.find_route(hot_url).app
              expect(BlueGreenDeploy.get_color_stem(hot_web_app)).to eq 'blue'
              CloudFoundryFake.started_apps.each do |worker_app|
                expect(BlueGreenDeploy.get_color_stem(worker_app.name)).to eq 'blue'
              end
            end
          end

          context 'there ARE hot worker apps' do
            before do
              CloudFoundryFake.init_app_list_from_names(worker_app_names)
              CloudFoundryFake.mark_app_as_started("#{worker_app_names.first}-blue")
            end
            it 'raises an InvalidRouteStateError' do
              expect{ subject }.to raise_error(InvalidRouteStateError)
            end
          end
        end
      end
    end

    describe '#get_hot_worker_names' do
      subject { BlueGreenDeploy.get_hot_worker_names }
      let(:target_color) { 'green' }

      context 'there are no started worker apps' do
        before do
          allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
          CloudFoundryFake.init_app_list_from_names(worker_app_names)
        end

        it 'returns an empty array' do
          expect(subject).to eq []
        end
      end

      context 'a worker app is started (and another is stopped)' do
        before do
          allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake)
          CloudFoundryFake.init_app_list_from_names(worker_app_names)
          CloudFoundryFake.mark_workers_as_started(worker_app_names, target_color)
        end

        it 'returns just the started worker app' do
          expect(subject).to eq(worker_app_names.map { |app_name| "#{app_name}-#{target_color}" })
        end
      end
    end

    describe '#ready_for_takeoff' do
      let(:target_color) { 'green' }
      subject { BlueGreenDeploy.ready_for_takeoff(hot_app_name, both_invalid_and_valid_hot_worker_names, deploy_config) }
      before { allow(BlueGreenDeploy).to receive(:cf).and_return(CloudFoundryFake) }

      context 'first deploy: there are no apps deployed' do
        let(:hot_app_name) { nil }
        let(:worker_app_names) { [] }
        let(:both_invalid_and_valid_hot_worker_names) { worker_app_names }
        before { CloudFoundryFake.init_app_list(worker_app_names) }

        it 'allows the deploy to proceed' do
          expect{ subject }.not_to raise_error
        end
      end

      context 'in subsequent deploys' do
        let(:hot_app_name) { "#{app_name}-#{current_hot_app}" }
        let(:worker_apps) { CloudFoundryFake.apps }
        let(:both_invalid_and_valid_hot_worker_names) { worker_apps.select { |app| app.state == 'started' }.map(&:name) }
        before do
          CloudFoundryFake.init_route_table(domain, app_name, hot_url, current_hot_app)
          CloudFoundryFake.init_app_list_with_workers_for(app_name)
        end
        context 'the target color is the cold app color.' do
          let(:current_hot_app) { 'blue' }
          let(:target_color) { 'green' }
          let(:deploy_config) do
            config = BlueGreenDeployConfig.new(cf_manifest, app_name, worker_app_names, with_shutter)
            config.target_color = target_color
            config
          end

          it 'does not raise an error: "It`s kosh!"' do
            expect{ subject }.to_not raise_error
          end

          context 'but, one or more of the target worker apps is already hot' do
            before do
              CloudFoundryFake.replace_app(App.new(name: "#{app_name}-worker-#{target_color}", state: 'started'))
              both_invalid_and_valid_hot_worker_names = ["#{app_name}-worker-#{target_color}"]
            end

            it 'raises an InvalidWorkerStateError' do
              expect{ subject }.to raise_error(InvalidWorkerStateError)
            end
          end
        end


        context 'and there is no current hot app and there are started worker apps' do
          let(:target_color) { nil }
          let(:current_hot_app) { '' }
          let(:hot_app_name) { nil }
          before do
            CloudFoundryFake.remove_route(hot_url)
            CloudFoundryFake.mark_app_as_started(CloudFoundryFake.apps.sample.name)
          end

          it 'raises an InvalidRouteStateError' do
            expect{ subject }.to raise_error(InvalidRouteStateError)
          end
        end
      end
    end

    describe '#get_hot_web_app' do
      subject { BlueGreenDeploy.get_hot_web_app(hot_url) }
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
      let(:deploy_config) do
        config = BlueGreenDeployConfig.new(cf_manifest, app_name, worker_app_names, with_shutter)
        config.target_color = target_color
        config
      end
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
          expect(BlueGreenDeploy.get_hot_web_app(hot_url)).to eq "#{app_name}-#{target_color}"
        end
      end

      context 'when there IS a hot URL route, but it is not mapped to any app' do
        before do
          CloudFoundryFake.remove_route(hot_url)
          CloudFoundryFake.add_route(Route.new(hot_url, domain, nil))

        end

        it 'the target_color is mapped to the hot_url' do
          subject
          expect(BlueGreenDeploy.get_hot_web_app(hot_url)).to eq "#{app_name}-#{target_color}"
        end
      end

      context 'when the hot url IS mapped to an app, already' do
        it 'the app that was mapped to the hot_url is no longer mapped to hot_url' do
          subject
          expect(BlueGreenDeploy.get_hot_web_app(hot_url)).to_not eq "#{app_name}-#{current_hot_app}"
        end

        it 'the target_color is mapped to the hot_url' do
          subject
          expect(BlueGreenDeploy.get_hot_web_app(hot_url)).to eq "#{app_name}-#{target_color}"
        end
      end
    end
  end
end
