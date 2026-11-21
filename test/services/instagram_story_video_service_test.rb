require "test_helper"

class InstagramStoryVideoServiceTest < ActiveSupport::TestCase
  # Parallel test workers would otherwise contend for the one host-wide lock.
  setup do
    @lock_path = Rails.root.join("tmp/story_video-test-#{Process.pid}.lock")
    InstagramStoryVideoService.lock_path = @lock_path
  end

  teardown do
    InstagramStoryVideoService.lock_path = Rails.root.join("tmp/story_video.lock")
    FileUtils.rm_f(@lock_path)
  end

  test "a second encode is refused while one is running" do
    File.open(@lock_path, File::RDWR | File::CREAT) do |held|
      held.flock(File::LOCK_EX)
      # flock is per open file, so a second open in this process contends like
      # another Puma thread would.
      assert_raises(InstagramStoryVideoService::Busy) do
        InstagramStoryVideoService.new(Article.new).generate
      end
    end
  end

  test "the lock is released after an encode" do
    assert_nil InstagramStoryVideoService.new(Article.new).generate # no image
    assert_nil InstagramStoryVideoService.new(Article.new).generate
  end

  test "a command past its time limit is killed" do
    started = Time.now
    error = assert_raises(RuntimeError) do
      InstagramStoryVideoService.run_limited([ "sleep", "10" ], timeout: 0.5)
    end
    assert_match(/longer than/, error.message)
    assert_operator Time.now - started, :<, 3
  end

  test "a failing command raises with its stderr" do
    error = assert_raises(RuntimeError) do
      InstagramStoryVideoService.run_limited([ "sh", "-c", "echo boom >&2; exit 1" ])
    end
    assert_match(/boom/, error.message)
  end

  test "a succeeding command returns" do
    assert_nothing_raised { InstagramStoryVideoService.run_limited([ "true" ]) }
  end
end
