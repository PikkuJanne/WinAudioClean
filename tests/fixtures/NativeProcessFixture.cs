// Benign Windows process fixture. It records actual argv and can emulate only
// the process/file effects needed by tests; its output is not valid audio.
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

internal static class NativeProcessFixture
{
    private static string Setting(string name)
    {
        return Environment.GetEnvironmentVariable("WAC_TEST_" + name);
    }

    private static int Number(string name)
    {
        string value = Setting(name);
        return String.IsNullOrEmpty(value) ? 0 : Int32.Parse(value, CultureInfo.InvariantCulture);
    }

    private static string JsonArguments(string[] args)
    {
        StringBuilder json = new StringBuilder("[");
        for (int index = 0; index < args.Length; index++)
        {
            if (index != 0) json.Append(',');
            json.Append('"');
            foreach (char character in args[index])
            {
                if (character == '"' || character == '\\')
                    json.Append('\\').Append(character);
                else if (character < 32)
                    json.Append("\\u").Append(((int)character).ToString("x4", CultureInfo.InvariantCulture));
                else
                    json.Append(character);
            }
            json.Append('"');
        }
        return json.Append(']').ToString();
    }

    private static void WriteStream(TextWriter writer, char character, int count, string ending)
    {
        string chunk = new String(character, 4096);
        while (count > 0)
        {
            int length = Math.Min(count, chunk.Length);
            writer.Write(chunk.Substring(0, length));
            count -= length;
        }
        writer.Write(ending);
        writer.Flush();
    }

    private static string FindOutput(string[] args)
    {
        string output = Setting("OUTPUT_PATH");
        if (!String.IsNullOrEmpty(output)) return output;
        if (Setting("FFMPEG_OUTPUT") != "1") return null;

        string input = null;
        for (int index = 0; index < args.Length; index++)
        {
            if (args[index] == "-i" && index + 1 < args.Length)
            {
                input = args[++index];
                continue;
            }
            if (args[index].EndsWith(".wav", StringComparison.OrdinalIgnoreCase))
                output = args[index];
        }
        if (String.IsNullOrEmpty(output)) throw new InvalidOperationException("Fixture could not find a WAV output argument.");
        if (String.Equals(output, input, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Fixture refuses to replace its input.");
        return output;
    }

    private static int Main(string[] args)
    {
        try
        {
            Console.OutputEncoding = new UTF8Encoding(false);
            string argvPath = Setting("ARGV_PATH");
            if (!String.IsNullOrEmpty(argvPath))
                File.WriteAllText(argvPath, JsonArguments(args), new UTF8Encoding(false));
            string pidPath = Setting("PID_PATH");
            if (!String.IsNullOrEmpty(pidPath))
                File.WriteAllText(pidPath, Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture));

            if (Setting("READ_STDIN") == "1")
            {
                string input = Console.In.ReadToEnd();
                Console.Out.Write("STDIN_EOF:" + input.Length.ToString(CultureInfo.InvariantCulture));
            }

            int streamCount = Number("STREAM_BYTES");
            if (streamCount > 0)
            {
                // Parallel writers exceed pipe capacity independently. A parent
                // that reads one stream and then the other can deadlock here.
                Thread stdout = new Thread(delegate() { WriteStream(Console.Out, 'O', streamCount, "STDOUT_END"); });
                Thread stderr = new Thread(delegate() { WriteStream(Console.Error, 'E', streamCount, "STDERR_END"); });
                stdout.Start();
                stderr.Start();
                stdout.Join();
                stderr.Join();
            }
            Console.Out.Write(Setting("STDOUT") ?? String.Empty);
            Console.Error.Write(Setting("STDERR") ?? String.Empty);
            Console.Out.Flush();
            Console.Error.Flush();

            int delay = Number("SLEEP_MS");
            if (delay > 0) Thread.Sleep(delay);
            int exitCode = Number("EXIT_CODE");
            string outputPath = FindOutput(args);
            if (exitCode == 0 && !String.IsNullOrEmpty(outputPath))
                File.WriteAllBytes(outputPath, new byte[] { 82, 73, 70, 70, 1, 2, 3, 4 });
            if (Setting("BLOCK_LOG") == "1")
            {
                if (String.IsNullOrEmpty(outputPath)) throw new InvalidOperationException("A fixture output path is required to block logging.");
                Directory.CreateDirectory(Path.Combine(Path.GetDirectoryName(outputPath), "WinAudioClean_Log.txt"));
            }
            return exitCode;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("NATIVE_FIXTURE_ERROR: " + error.Message);
            return 97;
        }
    }
}
