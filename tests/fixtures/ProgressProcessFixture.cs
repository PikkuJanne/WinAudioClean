// Dedicated benign structured-progress fixture. It starts no other processes.
// All paths and controls come from test-owned WAC_PROGRESS_TEST_* environment.
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

internal static class ProgressProcessFixture
{
    private static string Setting(string name)
    {
        return Environment.GetEnvironmentVariable("WAC_PROGRESS_TEST_" + name);
    }

    private static int Number(string name, int defaultValue)
    {
        string value = Setting(name);
        return String.IsNullOrEmpty(value) ? defaultValue : Int32.Parse(value, CultureInfo.InvariantCulture);
    }

    private static void WriteDiagnostic()
    {
        int remaining = Number("DIAGNOSTIC_BYTES", 0);
        string chunk = new string('D', 4096);
        while (remaining > 0)
        {
            int count = Math.Min(remaining, chunk.Length);
            Console.Error.Write(chunk.Substring(0, count));
            remaining -= count;
        }
        string marker = Setting("STDERR");
        Console.Error.Write(String.IsNullOrEmpty(marker) ? "DIAGNOSTIC_MARKER" : marker);
        Console.Error.Flush();
    }

    public static int Main()
    {
        try
        {
            Console.OutputEncoding = new UTF8Encoding(false);
            string pidPath = Setting("PID_PATH");
            if (!String.IsNullOrEmpty(pidPath))
                File.WriteAllText(pidPath, Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture));
            string readyPath = Setting("READY_PATH");
            if (!String.IsNullOrEmpty(readyPath)) File.WriteAllText(readyPath, "READY");
            string outputPath = Setting("PARTIAL_PATH");
            if (!String.IsNullOrEmpty(outputPath)) File.WriteAllBytes(outputPath, new byte[] { 41, 42, 43 });
            if (Setting("MODE") == "survivor")
            {
                Thread.Sleep(Number("SLEEP_MS", 15000));
                return 0;
            }
            Thread diagnostic = new Thread(WriteDiagnostic);
            diagnostic.Start();
            string textPath = Setting("TEXT_PATH");
            string text = String.IsNullOrEmpty(textPath) ? Setting("TEXT") : File.ReadAllText(textPath, new UTF8Encoding(false, true));
            if (String.IsNullOrEmpty(text)) text = "out_time_us=0\nprogress=continue\nout_time_us=1000000\nprogress=end\n";
            int chunkSize = Math.Max(1, Number("CHUNK_SIZE", 4096));
            int delay = Number("CHUNK_DELAY_MS", 0);
            for (int offset = 0; offset < text.Length; offset += chunkSize)
            {
                Console.Out.Write(text.Substring(offset, Math.Min(chunkSize, text.Length - offset)));
                Console.Out.Flush();
                if (delay > 0) Thread.Sleep(delay);
            }
            if (Setting("READ_STDIN") == "1")
            {
                long bytes = 0;
                byte[] buffer = new byte[8192];
                Stream input = Console.OpenStandardInput();
                int received;
                while ((received = input.Read(buffer, 0, buffer.Length)) != 0) bytes += received;
                Console.Error.Write("STDIN_EOF:" + bytes.ToString(CultureInfo.InvariantCulture));
                Console.Error.Flush();
            }
            Thread.Sleep(Number("SLEEP_MS", 0));
            diagnostic.Join();
            return Number("EXIT_CODE", 0);
        }
        catch (Exception error)
        {
            Console.Error.Write("PROGRESS_FIXTURE_ERROR:" + error.Message);
            return 97;
        }
    }
}
