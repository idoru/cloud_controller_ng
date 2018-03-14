require 'spec_helper'

module VCAP::CloudController::Buildpack
  RSpec.describe StackNameExtractor do
    let(:tmpdir) { Dir.mktmpdir }
    let(:filename) { 'file.zip' }

    def zip_with_manifest_content(manifest_content)
      zip_path = File.join(tmpdir, filename)
      TestZip.create(zip_path, 1, 1024) do |zipfile|
        if valid_zip_manifest_stack
          zipfile.get_output_stream('manifest.yml') do |f|
            f.write(manifest_content)
          end
        end
      end
      zip_path
    end


    describe '.extract_stack_from_file' do
      context 'buildpack zip is not a valid zip file' do
        let(:invalid_zip) do
          zip_path = File.join(tmpdir, filename)
          File.write(zip_path, "INVALID_FOR_A_ZIP_FILE_THIS_IS")
          zip_path
        end

        it 'raises an error' do

        end
      end

      context 'buildpack zip contains a manifest specifying the stack' do 
        let(:zip_with_manifest_with_stack) do
          zip_with_manifest_content("---\nstack: ITSaSTACK\n")
        end

        it 'returns the stack in the manifest' do

        end
      end

      context 'buildpack zip contains manifest that does not specify stack' do
        let(:zip_with_manifest_without_stack) do
          zip_with_manifest_content("---\nsomethingelse: NOTstackTHOUGH\n")
        end

        it 'returns nil' do

        end
      end

      context 'buildpack zip contains manifest which is not valid' do
        let(:zip_with_invalid_manifest) do
          zip_with_manifest_content("\0xde\0xad\0xbe\0xef")
        end

        it 'raises an error' do

        end
      end

      context 'buildpack zip does not contain manifest' do
        let(:zip_without_manifest) do
          zip_path = File.join(tmpdir, filename)
          TestZip.create(zip_path, 3, 1024)
          zip_path
        end

        it 'returns nil' do

        end
      end

      context 'buildpack zip contains manifest but it is too large (>1mb)' do
        let(:zip_with_massive_manifest) do
          alphachars = [*'A'..'Z']
          megabyte_string = (0...(1024*1024)).map { alphachars.sample }.join
          zip_with_manifest_content("---\nstack: cflinuxfs2\nabsurdly_long_value: " + megabyte_string)
        end

        it 'raises an error' do

        end
      end
    end



#### vvv from upload_buildpack_spec
      context 'and the upload to the blobstore succeeds' do
        context 'stack from manifest' do
          context 'manifest file is too large (>1mb)' do
            let(:valid_zip_manifest_stack) { 'cflinuxfs2' }
              zip_file = File.new(zip_name)
              Rack::Test::UploadedFile.new(zip_file)
            end

            it 'returns an error and does not update stack' do
              expect { upload_buildpack.upload_buildpack(buildpack, zip_with_massive_manifest, filename) }.to raise_error(CloudController::Errors::ApiError)
              bp = Buildpack.find(name: buildpack.name)
              expect(bp).to_not be_nil
              expect(bp.stack).to eq('cflinuxfs2')
            end
          end

          context 'same as buildpack' do
            let(:valid_zip_manifest_stack) { 'cflinuxfs2' }

            it 'copies new bits to the blobstore' do
              expect(buildpack_blobstore).to receive(:cp_to_blobstore).with(valid_zip, expected_sha_valid_zip)

              upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
            end
          end

          context 'different from buildpack' do
            let(:valid_zip_manifest_stack) { 'cflinuxfs3' }
            before do
              VCAP::CloudController::Stack.create(name: 'cflinuxfs3')
            end

            it 'raises an error and does not update stack' do
              expect { upload_buildpack.upload_buildpack(buildpack, valid_zip, filename) }.to raise_error(CloudController::Errors::ApiError)
              bp = Buildpack.find(name: buildpack.name)
              expect(bp).to_not be_nil
              expect(bp.stack).to eq('cflinuxfs2')
            end
          end

          context 'stack previously unknown' do
            let!(:buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: 'unknown', position: 0 }) }
            context 'known' do
              let(:valid_zip_manifest_stack) { 'cflinuxfs3' }
              before do
                VCAP::CloudController::Stack.create(name: 'cflinuxfs3')
              end

              it 'copies new bits to the blobstore and updates the stack' do
                expect(buildpack_blobstore).to receive(:cp_to_blobstore).with(valid_zip, expected_sha_valid_zip)

                expect do
                  upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
                end.to change { buildpack.stack }.from('unknown').to('cflinuxfs3')
              end

              context 'buildpack with same name and stack exists' do
                let(:valid_zip_manifest_stack) { 'cflinuxfs3' }

                it 'raises an error' do
                  VCAP::CloudController::Buildpack.create(name: buildpack.name, stack: 'cflinuxfs3')
                  expect { upload_buildpack.upload_buildpack(buildpack, valid_zip, filename) }.to raise_error(CloudController::Errors::ApiError)
                end
              end
            end

            context 'unknown' do
              let(:valid_zip_manifest_stack) { 'new-and-unknown' }
              it 'raises an error' do
                expect { upload_buildpack.upload_buildpack(buildpack, valid_zip, filename) }.to raise_error(CloudController::Errors::ApiError)
                bp = Buildpack.find(name: buildpack.name)
                expect(bp).to_not be_nil
                expect(bp.filename).to be_nil
              end
            end
          end
        end

        it 'updates the buildpack filename' do
          expect {
            upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          }.to change {
            Buildpack.find(name: 'upload_binary_buildpack').filename
          }.from(nil).to(filename)
        end

        context 'new bits (new sha)' do
          it 'copies new bits to the blobstore and updates the key and checksum' do
            expect(buildpack_blobstore).to receive(:cp_to_blobstore).with(valid_zip, expected_sha_valid_zip)

            expect(buildpack.key).to be_nil
            expect(buildpack.sha256_checksum).to be_nil

            upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)

            expect(buildpack.key).to eq(expected_sha_valid_zip)
            expect(buildpack.sha256_checksum).to eq(sha_valid_zip)
          end

          it 'does not attempt to delete the old buildpack blob when it does not exist' do
            expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
            upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          end

          context 'when there is an old buildpack in the blobstore' do
            before { buildpack.update(key: 'existing_key') }

            it 'removes the old buildpack binary when a new one is uploaded' do
              allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)
              upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
              expect(VCAP::CloudController::BuildpackBitsDelete).to have_received(:delete_when_safe).with('existing_key', staging_timeout)
            end
          end

          context 'when two upload_buildpack calls are running at the same time' do
            it 'does not delete the buildpack' do
              expect(buildpack_blobstore).to receive(:cp_to_blobstore) do
                Buildpack.find(name: 'upload_binary_buildpack').update(key: expected_sha_valid_zip)
              end

              expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be true
            end
          end
        end

        context 'same bits (same sha)' do
          before do
            buildpack.update(key: expected_sha_valid_zip, filename: filename)
          end

          context 'when bits provided are already in the blobstore' do
            before do
              allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(true)
            end

            it 'does not copy bits to the blobstore if nothing has changed' do
              expect(buildpack_blobstore).not_to receive(:cp_to_blobstore)
              expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be false
            end
          end

          context 'when the bit are missing from the blobstore' do
            before do
              allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(false)
            end

            it 'returns true if the bits are uploaded and does not remove the bits' do
              expect(buildpack_blobstore).to receive(:cp_to_blobstore)
              expect(VCAP::CloudController::BuildpackBitsDelete).not_to receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be true
            end
          end
        end

        context 'when the same bits are uploaded twice' do
          let(:buildpack2) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'buildpack2', stack: 'cflinuxfs2', position: 0 }) }

          it 'should have different keys' do
            upload_buildpack.upload_buildpack(buildpack, valid_zip2, filename)
            upload_buildpack.upload_buildpack(buildpack2, valid_zip2, filename)
            bp1 = Buildpack.find(name: 'upload_binary_buildpack')
            bp2 = Buildpack.find(name: 'buildpack2')
            expect(bp1.key).to_not eq(bp2.key)
          end
        end
      end

      context 'and the upload to the blobstore fails' do
        let(:previous_key) { 'previous_key' }
        let(:previous_filename) { 'previous_filename' }

        before do
          allow(buildpack_blobstore).to receive(:cp_to_blobstore).and_raise
          buildpack.update(key: previous_key, filename: previous_filename)
        end

        it 'should not update the key and filename on the existing buildpack' do
          expect { upload_buildpack.upload_buildpack(buildpack, valid_zip, filename) }.to raise_error(RuntimeError)
          bp = Buildpack.find(name: buildpack.name)
          expect(bp).to_not be_nil
          expect(bp.key).to eq(previous_key)
          expect(bp.filename).to eq(previous_filename)
        end
      end

      context 'when updating the buildpack fails' do
        before do
          allow(buildpack_blobstore).to receive(:cp_to_blobstore) do
            buildpack.delete
          end
        end

        it 'deletes the uploaded blob from the blobstore' do
          allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)

          upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          expect(BuildpackBitsDelete).to have_received(:delete_when_safe).with(expected_sha_valid_zip, 0)
        end
      end

      context 'when the buildpack is locked' do
        before { buildpack.update(locked: true) }

        it 'does nothing' do
          expect(buildpack_blobstore).to_not receive(:cp_to_blobstore)
          expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be false
        end
      end
    end
  end
end
