require('test_helper')
require('open3')
require('json')

class PromptTest < Minitest::Test
  # PROMPT_BIN = File.expand_path('../prompt.rb', __dir__)
  PROMPT_BIN = File.expand_path('../target/debug/shell-prompt', __dir__)

  def test_path_info
    assert_equal(
      "%{\e[34m\e[48;5;238m%}neato%{\e[0m%}",
      gen('-p'),
    )
    assert_equal(
      "%{\e[34m%}neato%{\e[0m%}",
      gen('-p', shadowenv_data: '0000000'),
    )
    assert_equal(
      "%{\e[32m\e[48;5;238m%}neato%{\e[0m%}",
      gen('-p', env: { 'SSH_CONNECTION' => '1' }),
    )
  end

  def test_all
    File.write("#{@rtg}/shell-prompt-#{Process.pid}.json", {
      exec_no: 1,
      content: "\x1b[35m",
      pid: nil,
    }.to_json)
    exp = [
      "%{\e[34m\e[48;5;238m%}neato%{\e[0m%}",
      ' ',
      "%{\e[35m%}",
      '𝒎',
      "%{\e[33m%} ≟",
      ' ',
      "%{\e[33m%}%#%{\e[0m%}",
      '%(1j.%j.) ',
    ].join('')
    assert_equal(exp, gen)
  end

  def test_stashinfo
    assert_equal('', gen('-s'))
    FileUtils.touch('stash')
    %x{git add * && git stash}
    assert_equal("%{\e[37m%}¹%{\e[0m%}", gen('-s'))
    8.times do |i|
      FileUtils.touch("stash#{i}")
      %x{git add * && git stash}
    end
    assert_equal("%{\e[37m%}⁹%{\e[0m%}", gen('-s'))
    FileUtils.touch('stash_n')
    %x{git add * && git stash}
    assert_equal("%{\e[37m%}⁹%{\e[0m%}", gen('-s'))
  end

  def test_async_data
    skip
    assert_equal('', gen('-a'))
  end

  def test_refinfo
    assert_equal('𝒎', gen('-r'))
    git('checkout', '-b', 'main')
    assert_equal('𝒎', gen('-r'))
    git('checkout', '-b', 'asdf')
    assert_equal('asdf', gen('-r'))
    z = git('rev-parse', 'HEAD').chomp
    git('checkout', z)
    assert_equal('698d6fd2', gen('-r'))
  end

  def test_pending
    # creating these actual situations is too much of a pain, so...
    markers = {
      'CHERRY_PICK_HEAD' => 'ᴾ',
      'MERGE_HEAD' => 'ᴹ',
      'BISECT_LOG' => 'ᴮ',
      'rebase-apply' => 'ᴿ',
      'rebase-merge' => 'ʳ',
    }
    assert_equal('', gen('-n'))
    markers.each do |k, v|
      markers.each do |k2, _|
        File.unlink(".git/#{k2}")
      rescue Errno::ENOENT
        nil
      end
      FileUtils.touch(".git/#{k}")
      assert_equal("%{\x1b[31m%}#{v}", gen('-n'))
    end
  end

  def test_no_git
    Dir.chdir('/') do
      assert_equal('', gen('-s'))
      assert_equal('', gen('-r'))
      assert_equal('', gen('-n'))
      assert_equal('', gen('-y'))
    end
  end

  def test_syncstat
    FileUtils.mkdir_p('.git/refs/remotes/origin')
    rev = git('rev-parse', 'HEAD').chomp
    File.write('.git/refs/remotes/origin/master', rev)
    assert_equal('', gen('-y')) # match
    File.write('.git/refs/remotes/origin/master', 'no-match')
    assert_equal("%{\e[31m%} ≠", gen('-y'))
    File.unlink('.git/refs/remotes/origin/master')
    assert_equal("%{\e[33m%} ≟", gen('-y'))
  end

  def test_exit_status
    assert_equal('', gen('-e'))
    assert_equal("%{\e[31m%}1%{\e[0m%}", gen('-e', exit_status: '1'))
    assert_equal("%{\e[31m%}190%{\e[0m%}", gen('-e', exit_status: '190'))
    assert_equal("%{\e[31m%}?%{\e[0m%}", gen('-e', exit_status: nil))
  end

  def test_prompt_char
    assert_equal("%{\x1b[33m%}%#%{\x1b[0m%}", gen('-P'))
  end

  def test_jobs
    assert_equal('%(1j.%j.)', gen('-j'))
  end

  def git(*args)
    o, err, stat = Open3.capture3('git', *args)
    assert(stat.success?, err)
    o
  end

  def run(*)
    Dir.mktmpdir do |dir|
      @rtg = ENV['XDG_RUNTIME_DIR'] = dir
      @alrm_count = 0
      trap(:ALRM) { @alrm_count += 1 }
      Dir.mktmpdir do |dir|
        neato_tgz = File.expand_path('fixtures/neato.tgz', __dir__)
        %x{tar xzf #{neato_tgz} -C #{dir}}
        Dir.chdir(File.join(dir, 'neato')) { super }
      end
    end
  end

  private

  def gen(
    *fragments,
    shell_pid: Process.pid.to_s, ps1_exec_no: '1', shadowenv_data: '12345678',
    exit_status: '0', env: {}
  )
    out, err, stat = Open3.capture3({
      'HOME' => '/missing', # just to dodge git's config
      'SHELL_PID' => shell_pid,
      'PS1_EXEC_NO' => ps1_exec_no,
      'SHADOWENV_DATA' => shadowenv_data,
      'EXIT_STATUS' => exit_status,
    }.merge(env), PROMPT_BIN, *fragments)
    assert(stat.success?, err)
    out
  end
end
