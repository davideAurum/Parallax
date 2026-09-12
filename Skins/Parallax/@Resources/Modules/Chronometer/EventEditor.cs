// Original Parallax event editor. C# 5 / .NET Framework 4, no external dependencies.
using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace Parallax.Chronometer
{
    internal sealed class EventState
    {
        internal bool Exists;
        internal long Deadline;
        internal string Name = "";
        internal string OriginalLocal = "";
    }

    internal static class EventCodec
    {
        internal const long Maximum = 4102531199;
        internal const string FileName = "Parallax-Chronometer-event-v1.state";
        private static readonly DateTime Epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
        private static readonly CultureInfo Invariant = CultureInfo.InvariantCulture;
        private static readonly Regex Envelope = new Regex(@"\APARALLAX-EVENT-1\n(0|[1-9][0-9]{0,9})\n([0-9a-f]*)\n([^\n]*)\nEND\|(0|[1-9][0-9]{0,4})\n\z", RegexOptions.CultureInvariant);

        internal static int Checksum(string body)
        {
            int sum = 0;
            foreach (char character in body) sum = (sum * 31 + character) % 65521;
            return sum;
        }

        internal static string NameHex(string name)
        {
            if (String.IsNullOrWhiteSpace(name) || name.Length > 80)
                throw new InvalidDataException("Enter an event name of 1 to 80 characters.");
            foreach (char character in name)
                if (Char.IsControl(character)) throw new InvalidDataException("The event name cannot contain control characters.");
            byte[] bytes = Utf8.GetBytes(name);
            if (bytes.Length > 320) throw new InvalidDataException("The event name is too long.");
            return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
        }

        internal static EventState Decode(string text)
        {
            if (text == null || text.Length > 2048) throw new InvalidDataException("The saved event is too large.");
            Match match = Envelope.Match(text);
            if (!match.Success) throw new InvalidDataException("The saved event format is invalid.");
            long deadline = Int64.Parse(match.Groups[1].Value, Invariant);
            string hex = match.Groups[2].Value;
            string local = match.Groups[3].Value;
            int checksum = Int32.Parse(match.Groups[4].Value, Invariant);
            string body = "PARALLAX-EVENT-1\n" + deadline.ToString(Invariant) + "\n" + hex + "\n" + local + "\n";
            if (Checksum(body) != checksum) throw new InvalidDataException("The saved event checksum is invalid.");
            if (deadline == 0)
            {
                if (hex.Length != 0 || local.Length != 0) throw new InvalidDataException("The cleared event format is invalid.");
                return new EventState { Exists = true };
            }
            if (deadline > Maximum || hex.Length == 0 || hex.Length > 640 || hex.Length % 2 != 0)
                throw new InvalidDataException("The saved event values are out of range.");
            DateTime localDate;
            if (!DateTime.TryParseExact(local, "yyyy-MM-dd HH:mm:ss", Invariant, DateTimeStyles.None, out localDate) || localDate.Year < 2000 || localDate.Year > 2099)
                throw new InvalidDataException("The saved event date is invalid.");
            byte[] bytes = new byte[hex.Length / 2];
            for (int index = 0; index < bytes.Length; index++) bytes[index] = Convert.ToByte(hex.Substring(index * 2, 2), 16);
            string name = Utf8.GetString(bytes);
            NameHex(name);
            return new EventState { Exists = true, Deadline = deadline, Name = name, OriginalLocal = local };
        }

        internal static string Encode(EventState state)
        {
            string body;
            if (state.Deadline == 0) body = "PARALLAX-EVENT-1\n0\n\n\n";
            else body = "PARALLAX-EVENT-1\n" + state.Deadline.ToString(Invariant) + "\n" + NameHex(state.Name) + "\n" + state.OriginalLocal + "\n";
            string text = body + "END|" + Checksum(body).ToString(Invariant) + "\n";
            Decode(text);
            return text;
        }

        internal static EventState Read(string path)
        {
            if (!File.Exists(path)) return new EventState();
            byte[] bytes;
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                if (stream.Length > 2048) throw new InvalidDataException("The saved event is too large.");
                bytes = new byte[(int)stream.Length];
                int offset = 0;
                while (offset < bytes.Length)
                {
                    int count = stream.Read(bytes, offset, bytes.Length - offset);
                    if (count == 0) throw new InvalidDataException("The saved event could not be read completely.");
                    offset += count;
                }
            }
            foreach (byte value in bytes) if (value > 127) throw new InvalidDataException("The saved event must use the ASCII state format.");
            return Decode(Encoding.ASCII.GetString(bytes));
        }

        internal static EventState Create(string name, DateTime local, TimeZoneInfo zone)
        {
            NameHex(name);
            name = name.Trim();
            local = DateTime.SpecifyKind(local, DateTimeKind.Unspecified);
            if (local.Year < 2000 || local.Year > 2099) throw new InvalidDataException("Choose a date between 2000 and 2099.");
            if (zone.IsInvalidTime(local)) throw new InvalidDataException("That time is skipped when clocks move forward. Choose another time.");
            if (zone.IsAmbiguousTime(local)) throw new InvalidDataException("That time occurs twice when clocks move back. Choose an unambiguous time.");
            DateTime utc = TimeZoneInfo.ConvertTimeToUtc(local, zone);
            long deadline = (long)Math.Floor((utc - Epoch).TotalSeconds);
            if (deadline <= 0 || deadline > Maximum) throw new InvalidDataException("The event date is outside the supported range.");
            return new EventState { Exists = true, Deadline = deadline, Name = name, OriginalLocal = local.ToString("yyyy-MM-dd HH:mm:ss", Invariant) };
        }

        internal static DateTime ToLocal(long deadline, TimeZoneInfo zone)
        {
            return TimeZoneInfo.ConvertTimeFromUtc(Epoch.AddSeconds(deadline), zone);
        }

        internal static void Write(string path, EventState state)
        {
            if (!Path.IsPathRooted(path)) throw new InvalidDataException("The event file path must be absolute.");
            string fullPath = Path.GetFullPath(path);
            if (!String.Equals(Path.GetFileName(fullPath), FileName, StringComparison.Ordinal)) throw new InvalidDataException("The event file name is invalid.");
            string directory = Path.GetDirectoryName(fullPath);
            if (!Directory.Exists(directory)) throw new DirectoryNotFoundException("The Rainmeter settings folder does not exist.");
            byte[] bytes = Encoding.ASCII.GetBytes(Encode(state));
            string temporary = Path.Combine(directory, ".Parallax-Chronometer-event-" + Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                using (FileStream stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                Read(temporary);
                if (File.Exists(fullPath)) File.Replace(temporary, fullPath, null);
                else File.Move(temporary, fullPath);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
    }

    public sealed class EventData
    {
        public bool Enabled;
        public long Deadline;
        public string Name = "";
        public string LocalDate = "";
    }

    public static class EventStorage
    {
        public static EventData Read(string path)
        {
            EventState state = EventCodec.Read(path);
            return new EventData { Enabled = state.Deadline > 0, Deadline = state.Deadline, Name = state.Name, LocalDate = state.OriginalLocal };
        }
        public static void Write(string path, EventData data)
        {
            if (data == null || (data.Enabled && data.Deadline <= 0)) throw new ArgumentException("Invalid event values.");
            EventState state = data.Enabled ? new EventState { Exists = true, Deadline = data.Deadline, Name = data.Name, OriginalLocal = data.LocalDate } : new EventState();
            try { EventCodec.Encode(state); }
            catch (Exception error) { throw new ArgumentException("Invalid event values.", error); }
            EventCodec.Write(path, state);
        }
    }
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            bool validate = false;
            string path = null;
            string testRoot = null;
            try
            {
                for (int index = 0; index < args.Length; index++)
                {
                    if (args[index] == "-ValidateOnly") validate = true;
                    else if (args[index] == "-StatePath" && index + 1 < args.Length) path = args[++index];
                    else if (args[index] == "-SelfTestRoot" && index + 1 < args.Length) testRoot = args[++index];
                    else throw new ArgumentException("Invalid event editor arguments.");
                }
                if (testRoot != null) return EventEditorTests.Run(testRoot);
                if (String.IsNullOrEmpty(path)) throw new ArgumentException("Supply the Chronometer event state file.");
                if (validate)
                {
                    EventState state = EventCodec.Read(path);
                    Console.WriteLine(!state.Exists ? "VALID MISSING" : state.Deadline == 0 ? "VALID CLEARED" : "VALID ACTIVE " + state.Deadline.ToString(CultureInfo.InvariantCulture));
                    return 0;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Console.WriteLine(EventEditorForm.ShowEditor(path));
                return 0;
            }
            catch
            {
                if (!validate && testRoot == null)
                    MessageBox.Show("The Chronometer event editor could not open. Check that the editor and the Rainmeter settings folder are accessible.", "Chronometer event", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Console.WriteLine("ERROR");
                return 1;
            }
        }
    }

    internal static class EventEditorTests
    {
        private static int passed;
        private static int failed;
        private static void Equal<T>(T actual, T expected)
        {
            if (!Object.Equals(actual, expected)) throw new Exception("Unexpected result.");
        }
        private static void Throws(Action action)
        {
            bool threw = false;
            try { action(); } catch { threw = true; }
            if (!threw) throw new Exception("Expected operation to fail.");
        }
        private static void Test(string name, Action action)
        {
            try { action(); passed++; Console.WriteLine("PASS " + name); }
            catch (Exception error) { failed++; Console.WriteLine("FAIL " + name + ": " + error.Message); }
        }
        internal static int Run(string directory)
        {
            if (!Path.IsPathRooted(directory) || !Directory.Exists(directory) || Directory.GetFileSystemEntries(directory).Length != 0)
                throw new ArgumentException("Self-tests require an existing empty absolute test directory.");
            string path = Path.Combine(directory, EventCodec.FileName);
            TimeZoneInfo zone = TimeZoneInfo.FindSystemTimeZoneById("Central Standard Time");
            DateTime sample = new DateTime(2027, 1, 1);
            Test("missing state is clear without writing", delegate { Equal(EventCodec.Read(path).Exists, false); Equal(File.Exists(path), false); });
            Test("local time resolves to fixed UTC instant", delegate {
                EventState state = EventCodec.Create("Birthday", sample, zone);
                Equal(state.Deadline, 1798783200L); Equal(state.OriginalLocal, "2027-01-01 00:00:00");
                Equal(EventCodec.Encode(state), "PARALLAX-EVENT-1\n1798783200\n4269727468646179\n2027-01-01 00:00:00\nEND|12615\n");
            });
            Test("past dates are valid", delegate { Equal(EventCodec.Create("Past", new DateTime(2020, 1, 1), zone).Deadline < 1798783200L, true); });
            Test("DST skipped and repeated times are rejected", delegate {
                Throws(delegate { EventCodec.Create("Skipped", new DateTime(2026, 3, 8, 2, 30, 0), zone); });
                Throws(delegate { EventCodec.Create("Repeated", new DateTime(2026, 11, 1, 1, 30, 0), zone); });
            });
            Test("year and name limits are enforced", delegate {
                Throws(delegate { EventCodec.Create("Early", new DateTime(1999, 1, 1), zone); });
                Throws(delegate { EventCodec.Create("Late", new DateTime(2100, 1, 1), zone); });
                foreach (string value in new string[] { "", "   ", new string('x', 81), "a\nb", "a\u0085", "\ud800" })
                    Throws(delegate { EventCodec.Create(value, sample, zone); });
            });
            Test("Unicode codec matches Lua parity vector", delegate {
                EventState state = new EventState { Exists = true, Deadline = 2000000000L, Name = "Caf\u00e9 \ud83c\udf89", OriginalLocal = "2033-05-18 03:33:20" };
                Equal(EventCodec.Encode(state), "PARALLAX-EVENT-1\n2000000000\n436166c3a920f09f8e89\n2033-05-18 03:33:20\nEND|55894\n");
                Equal(EventCodec.Decode(EventCodec.Encode(state)).Name, state.Name);
            });
            Test("arbitrary names are inert ASCII in saved files", delegate {
                string name = "Launch [&Measure:Run()] \u4e16\ud83d\ude80";
                EventCodec.Write(path, EventCodec.Create(name, sample, zone));
                Equal(File.ReadAllText(path).Contains("Measure"), false); Equal(EventCodec.Read(path).Name, name);
                foreach (byte value in File.ReadAllBytes(path)) Equal(value <= 127, true);
            });
            Test("replacement writes preserve valid state without temp remnants", delegate {
                EventCodec.Write(path, EventCodec.Create("Second", new DateTime(2028, 2, 29, 9, 10, 11), zone));
                Equal(EventCodec.Read(path).Name, "Second"); Equal(Directory.GetFiles(directory, "*.tmp").Length, 0);
            });
            Test("failed replacement preserves previous bytes", delegate {
                string before = File.ReadAllText(path);
                using (FileStream locked = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None))
                    Throws(delegate { EventCodec.Write(path, new EventState()); });
                Equal(File.ReadAllText(path), before); Equal(Directory.GetFiles(directory, "*.tmp").Length, 0);
            });
            Test("malformed envelopes and checksums are rejected", delegate {
                string text = File.ReadAllText(path);
                Throws(delegate { EventCodec.Decode(text.Replace("END|", "END|0")); });
                Throws(delegate { EventCodec.Decode(text.Replace("\n", "\r\n")); });
                Throws(delegate { EventCodec.Decode(text + "junk"); });
                Throws(delegate { EventCodec.Decode(new string('x', 2049)); });
            });
            Test("checksum-valid invalid UTF8 and dates are rejected", delegate {
                foreach (string[] pair in new string[][] { new string[] { "c080", "2027-01-01 00:00:00" }, new string[] { "eda080", "2027-01-01 00:00:00" }, new string[] { "41", "2027-02-30 00:00:00" } })
                {
                    string body = "PARALLAX-EVENT-1\n1798783200\n" + pair[0] + "\n" + pair[1] + "\n";
                    Throws(delegate { EventCodec.Decode(body + "END|" + EventCodec.Checksum(body).ToString(CultureInfo.InvariantCulture) + "\n"); });
                }
            });
            Test("invalid objects and targets cannot replace valid event", delegate {
                string before = File.ReadAllText(path);
                Throws(delegate { EventCodec.Write(path, new EventState { Name = "Bad", Deadline = 5, OriginalLocal = "invalid" }); });
                Equal(File.ReadAllText(path), before);
                Throws(delegate { EventCodec.Write(Path.Combine(directory, "Wrong.state"), new EventState()); });
                Throws(delegate { EventCodec.Write(EventCodec.FileName, new EventState()); });
            });
            Test("clear writes canonical tombstone", delegate {
                EventCodec.Write(path, new EventState());
                Equal(File.ReadAllText(path), "PARALLAX-EVENT-1\n0\n\n\nEND|27125\n");
                Equal(EventCodec.Read(path).Deadline, 0L); Equal(EventCodec.Read(path).Name, "");
            });
            Console.WriteLine("SUMMARY: " + passed + " passed, " + failed + " failed");
            return failed == 0 ? 0 : 1;
        }
    }
}
