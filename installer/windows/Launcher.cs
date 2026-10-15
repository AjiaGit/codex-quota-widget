using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher {
    [STAThread]
    private static int Main(string[] args) {
        bool quit = args.Length > 0 && args[0] == "--quit";
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(root, quit ? "Stop.ps1" : "Start.ps1");
        string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
        try {
            var start = new ProcessStartInfo {
                FileName = powershell,
                Arguments = "-NoProfile -Sta -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                WorkingDirectory = root,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process process = Process.Start(start);
            if (process == null) throw new InvalidOperationException("PowerShell did not start.");
            process.Dispose();
            return 0;
        } catch {
            bool chinese = System.Globalization.CultureInfo.CurrentUICulture.Name.StartsWith("zh", StringComparison.OrdinalIgnoreCase);
            try {
                string preferences = Path.Combine(Environment.GetEnvironmentVariable("LOCALAPPDATA") ?? Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"CodexWeeklyMonitor\settings.json");
                var match = System.Text.RegularExpressions.Regex.Match(File.ReadAllText(preferences), "\"language\"\\s*:\\s*\"(auto|en|zh-CN)\"");
                if (match.Success && match.Groups[1].Value != "auto") chinese = match.Groups[1].Value == "zh-CN";
            } catch { }
            MessageBox.Show(chinese ? "无法启动 Codex 额度悬浮窗，请重新安装后重试。" : "Codex Quota could not start. Reinstall and try again.", chinese ? "Codex 额度悬浮窗" : "Codex Quota", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
