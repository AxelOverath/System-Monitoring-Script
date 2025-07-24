Describe "Collect-SystemMetrics" {
    It "Returns objects with CPU, Memory, Disk properties" {
        $result = Collect-SystemMetrics -Servers @('localhost') -Threads 1
        $result | Should -Not -BeNullOrEmpty
        $result | ForEach-Object {
            $_ | Should -HaveProperty CPU
            $_ | Should -HaveProperty Memory
            $_ | Should -HaveProperty Disk
        }
    }
}
