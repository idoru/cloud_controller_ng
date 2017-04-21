require 'spec_helper'
require 'membrane'
require 'cloud_controller/diego/failure_reason_sanitizer'

module VCAP::CloudController
  RSpec.describe StagingCompletionController do
    let(:buildpack) { Buildpack.make }
    let(:buildpack_key) { buildpack.key }
    let(:detected_buildpack) { 'detected_buildpack' }
    let(:execution_metadata) { 'execution_metadata' }
    let(:staging_response) do
      {
        result: {
          lifecycle_type: 'buildpack',
          lifecycle_metadata: {
            buildpack_key: buildpack_key,
            detected_buildpack: detected_buildpack,
          },
          execution_metadata: execution_metadata,
          process_types: { web: 'start me' }
        }
      }
    end

    context 'staging a package through /droplet_completed' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/droplet_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: staged_app.guid, state: DropletModel::STAGING_STATE) }
      let(:staging_guid) { droplet.guid }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      it 'calls the stager with the droplet and response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, staging_response, false)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200)
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match /JobTimeout/
      end

      context 'when receiving the callback directly from BBS' do
        let(:staging_result) do
          {
            lifecycle_type: 'buildpack',
            lifecycle_metadata: {
              buildpack_key: buildpack_key,
              detected_buildpack: detected_buildpack,
            },
            execution_metadata: execution_metadata,
            process_types: { web: 'start me' }
          }
        end
        let(:failure_reason) { '' }
        let(:sanitized_failure_reason) { double(:sanitized_failure_reason) }
        let(:staging_result_json) { MultiJson.dump(staging_result) }
        let(:staging_response) do
          {
            failed: failure_reason.present?,
            failure_reason: failure_reason,
            result: staging_result_json,
          }
        end

        before do
          allow(Diego::FailureReasonSanitizer).to receive(:sanitize).with(failure_reason).and_return(sanitized_failure_reason)
        end

        it 'calls the stager with the droplet and response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, { result: staging_result }, false)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'propagates api errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(524)
          expect(last_response.body).to match /JobTimeout/
        end

        context 'when staging failed' do
          let(:failure_reason) { 'something went wrong' }
          let(:staging_result_json) { nil }

          it 'passes down the sanitized version of the error to the diego stager' do
            expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, { error: sanitized_failure_reason }, false)

            post url, MultiJson.dump(staging_response)
          end
        end
      end

      context 'when the droplet does not exist' do
        let(:staging_guid) { 'asdf' }

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match /Droplet not found/
        end
      end

      context 'when the start query param has a true value' do
        it 'requests staging_complete with start' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, staging_response, true)

          post "#{url}?start=true", MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
      end

      describe 'authentication' do
        context 'when missing authentication' do
          it 'fails with authentication required' do
            header('Authorization', nil)
            post url, staging_response
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using invalid credentials' do
          it 'fails with authenticatiom required' do
            authorize 'bar', 'foo'
            post url, staging_response
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using valid credentials' do
          it 'succeeds' do
            allow_any_instance_of(Diego::Stager).to receive(:staging_complete)
            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match /MessageParseError/
          end
        end
      end
    end

    context 'staging a package through /build_completed after droplet has been uploaded' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/build_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let!(:droplet) { DropletModel.make }
      let(:build) { BuildModel.make(package_guid: package.guid) }
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(buildpack: buildpack, stack: 'cflinuxfs2', build: build) }
      let(:staging_guid) { build.guid }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
        build.droplet = droplet
      end

      it 'calls the stager with the droplet and response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(DropletModel), staging_response, false)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200), last_response.body
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match /JobTimeout/
      end

      context 'when receiving the callback directly from BBS' do
        let(:staging_result) do
          {
            lifecycle_type: 'buildpack',
            lifecycle_metadata: {
              buildpack_key: buildpack_key,
              detected_buildpack: detected_buildpack,
            },
            execution_metadata: execution_metadata,
            process_types: { web: 'start me' }
          }
        end
        let(:failure_reason) { '' }
        let(:sanitized_failure_reason) { double(:sanitized_failure_reason) }
        let(:staging_result_json) { MultiJson.dump(staging_result) }
        let(:staging_response) do
          {
            failed: failure_reason.present?,
            failure_reason: failure_reason,
            result: staging_result_json,
          }
        end

        before do
          allow(Diego::FailureReasonSanitizer).to receive(:sanitize).with(failure_reason).and_return(sanitized_failure_reason)
        end

        it 'calls the stager with the droplet and response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(DropletModel), { result: staging_result }, false)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'propagates api errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(524)
          expect(last_response.body).to match /JobTimeout/
          build.reload
          expect(build.state).to eq(BuildModel::FAILED_STATE)
          expect(build.error_description).to eq('Staging error: droplet failed to stage')
        end

        it 'propagates other errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(StandardError)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(500)
          expect(last_response.body).to match /ServerError/
          build.reload
          expect(build.state).to eq(BuildModel::FAILED_STATE)
          expect(build.error_description).to eq('Staging error: droplet failed to stage')
        end

        context 'when staging failed' do
          let(:failure_reason) { 'something went wrong' }
          let(:staging_result_json) { nil }

          it 'passes down the sanitized version of the error to the diego stager' do
            expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(DropletModel), { error: sanitized_failure_reason }, false)

            post url, MultiJson.dump(staging_response)
          end
        end
      end

      context 'when the build does not exist' do
        let(:staging_guid) { 'asdf' }

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match /Build not found/
        end
      end

      context 'when the start query param has a true value' do
        it 'requests staging_complete with start' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(DropletModel), staging_response, true)

          post "#{url}?start=true", MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
      end

      describe 'authentication' do
        context 'when missing authentication' do
          it 'fails with authentication required' do
            header('Authorization', nil)
            post url, staging_response
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using invalid credentials' do
          it 'fails with authenticatiom required' do
            authorize 'bar', 'foo'
            post url, staging_response
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using valid credentials' do
          it 'succeeds' do
            allow_any_instance_of(Diego::Stager).to receive(:staging_complete)
            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match /MessageParseError/
          end
        end
      end
    end

    context 'staging fails, calls back to /build_completed' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/build_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let(:build) { BuildModel.make(package_guid: package.guid) }
      let(:staging_guid) { build.guid }
      let(:staging_result) { nil }
      let(:staging_result_json) { MultiJson.dump(staging_result) }
      let(:staging_response) do
        {
          failed: failure_reason.present?,
          failure_reason: failure_reason,
          result: staging_result_json,
        }
      end

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      context 'no droplet was uploaded' do
        let!(:droplet) { nil }
        let(:failure_reason) { 'bad buildpack"' }
        let(:staging_error) do { error: 'bad buildpack' } end

        it 'sets the build to the failed state' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200), last_response.body
          build.reload
          expect(build.state).to eq(BuildModel::FAILED_STATE)
          expect(build.error_id).to eq(Diego::CCMessages::STAGING_ERROR)
          expect(build.error_description).to eq('Staging error: staging failed')
        end
      end

      context 'have droplet but staging failed' do
        let!(:droplet) { DropletModel.make }
        let(:failure_reason) { 'something went wrong' }

        before do
          build.droplet = droplet
        end

        it 'sets the build to the failed state' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
          build.reload
          expect(build.state).to eq(BuildModel::FAILED_STATE)
          expect(build.error_description).to eq('Staging error: staging failed')
          expect(build.error_id).to eq(Diego::CCMessages::STAGING_ERROR)
        end
      end
    end
  end
end
