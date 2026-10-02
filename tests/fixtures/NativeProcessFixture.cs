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

    private static bool TryInspectDependency(string[] args, out int exitCode)
    {
        exitCode = 0;
        string executable = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        bool ffmpeg = String.Equals(executable, "ffmpeg", StringComparison.OrdinalIgnoreCase);
        bool ffprobe = String.Equals(executable, "ffprobe", StringComparison.OrdinalIgnoreCase);
        if (!ffmpeg && !ffprobe) return false;

        string phase = null;
        string defaultOutput = null;
        if (Array.IndexOf(args, "-version") >= 0)
        {
            phase = "VERSION";
            defaultOutput = (ffmpeg ? "ffmpeg" : "ffprobe") + " version 9.0.2-wac-fixture\n";
        }
        else if (ffmpeg && Array.IndexOf(args, "-filters") >= 0)
        {
            phase = "FILTERS";
            defaultOutput = "Filters:\n ... adeclip A->A Fixture filter\n ... highpass A->A Fixture filter\n ... adeclick A->A Fixture filter\n ... afftdn A->A Fixture filter\n ... agate A->A Fixture filter\n ... dynaudnorm A->A Fixture filter\n ... loudnorm A->A Fixture filter\n";
        }
        else if (ffprobe && Array.IndexOf(args, "-show_entries") >= 0)
        {
            phase = "PROBE";
            defaultOutput = "{\"streams\":[{\"index\":0,\"codec_type\":\"audio\",\"codec_name\":\"pcm_s16le\",\"channels\":1,\"channel_layout\":\"mono\",\"sample_rate\":\"48000\"}]}";
        }
        if (phase == null) return false;

        // Dependency inspection has distinct controls so inherited render
        // failure/diagnostic settings do not prevent the application reaching
        // the render behavior that the earlier regression tests exercise.
        string argvPath = Setting(phase + "_ARGV_PATH");
        if (!String.IsNullOrEmpty(argvPath))
            File.WriteAllText(argvPath, JsonArguments(args), new UTF8Encoding(false));
        string pidPath = Setting(phase + "_PID_PATH");
        if (!String.IsNullOrEmpty(pidPath))
            File.WriteAllText(pidPath, Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture));
        Console.Out.Write(Setting(phase + "_STDOUT") ?? defaultOutput);
        Console.Error.Write(Setting(phase + "_STDERR") ?? String.Empty);
        Console.Out.Flush();
        Console.Error.Flush();
        int delay = Number(phase + "_SLEEP_MS");
        if (delay > 0) Thread.Sleep(delay);
        exitCode = Number(phase + "_EXIT_CODE");
        return true;
    }

    private static int Main(string[] args)
    {
        try
        {
            Console.OutputEncoding = new UTF8Encoding(false);
            int inspectionExit;
            if (TryInspectDependency(args, out inspectionExit)) return inspectionExit;
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
