require "testing_env"
require "hardware"

class HardwareTests < Homebrew::TestCase
  def test_hardware_cpu_type
    assert_includes [:intel, :ppc], Hardware::CPU.type
  end

  def test_hardware_arch
    assert_includes [:i386, :ppc, :ppc64, :x86_64], Hardware::CPU.arch
  end

  def test_hardware_intel_model
    models = [:core, :core2, :penryn, :nehalem, :arrandale, :sandybridge, :ivybridge, :haswell, :broadwell]
    assert_includes models, Hardware::CPU.model
  end if Hardware::CPU.intel?
end
