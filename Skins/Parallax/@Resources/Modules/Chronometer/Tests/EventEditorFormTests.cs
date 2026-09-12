// Tests the authored form's controller directly. No shown window or OS input APIs.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace Parallax.Chronometer
{
    internal static class EventEditorFormTests
    {
        private static int passed;
        private static int failed;
        private static readonly BindingFlags PrivateInstance = BindingFlags.Instance | BindingFlags.NonPublic;

        private static EventEditorForm Form(string path)
        {
            ConstructorInfo constructor = typeof(EventEditorForm).GetConstructor(PrivateInstance, null, new Type[] { typeof(string) }, null);
            return (EventEditorForm)constructor.Invoke(new object[] { path });
        }
        private static T Field<T>(EventEditorForm form, string name)
        {
            return (T)typeof(EventEditorForm).GetField(name, PrivateInstance).GetValue(form);
        }
        private static void Invoke(EventEditorForm form, string method)
        {
            typeof(EventEditorForm).GetMethod(method, PrivateInstance).Invoke(form, null);
        }
        private static void Equal<T>(T actual, T expected)
        {
            if (!Object.Equals(actual, expected)) throw new Exception("Expected " + expected + "; got " + actual);
        }
        private static void Test(string name, Action action)
        {
            try { action(); passed++; Console.WriteLine("PASS " + name); }
            catch (Exception error) { failed++; Console.WriteLine("FAIL " + name + ": " + error.Message); }
        }
        private static DateTime FutureDate() { return DateTime.Today.AddDays(14).AddHours(12); }
        private static void Select(EventEditorForm form, string name, DateTime local)
        {
            Field<TextBox>(form, "eventName").Text = name;
            Field<DateTimePicker>(form, "eventDate").Value = local.Date;
            Field<DateTimePicker>(form, "eventTime").Value = local;
        }
        private static void SaveFuture(string path)
        {
            using (EventEditorForm form = Form(path))
            {
                Select(form, "Release party", FutureDate());
                Invoke(form, "SaveEvent");
                Equal(Field<string>(form, "outcome"), "SAVED");
                EventData state = EventStorage.Read(path);
                Equal(state.Enabled, true);
                Equal(state.Name, "Release party");
                Equal(state.LocalDate, FutureDate().ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture));
            }
        }
        private static int Run(string directory, string preview)
        {
            if (!Path.IsPathRooted(directory) || !Directory.Exists(directory) || Directory.GetFileSystemEntries(directory).Length != 0)
                throw new ArgumentException("An existing empty absolute fixture directory is required.");
            string path = Path.Combine(directory, EventCodec.FileName);
            Test("form defaults to tomorrow at midnight and fits its controls", delegate {
                using (EventEditorForm form = Form(path))
                {
                    Equal(Field<TextBox>(form, "eventName").Text, "");
                    Equal(Field<DateTimePicker>(form, "eventDate").Value.Date, DateTime.Today.AddDays(1));
                    Equal(Field<DateTimePicker>(form, "eventTime").Value.TimeOfDay, TimeSpan.Zero);
                    Equal(Field<TextBox>(form, "eventName").MaxLength, 80);
                    Equal(form.Visible, false);
                    foreach (Control control in form.Controls)
                    {
                        if (control.Left < 0 || control.Top < 0 || control.Right > form.ClientSize.Width || control.Bottom > form.ClientSize.Height)
                            throw new Exception("Control leaves the form bounds: " + control.Text);
                    }
                }
                Equal(File.Exists(path), false);
            });
            Test("empty event name stays in form and does not write", delegate {
                using (EventEditorForm form = Form(path))
                {
                    Invoke(form, "SaveEvent");
                    Equal(Field<string>(form, "outcome"), "CANCELLED");
                    Equal(Field<Label>(form, "status").Text, "Enter an event name.");
                    Equal(File.Exists(path), false);
                }
            });
            Test("actual SaveEvent handler writes future event and reports SAVED", delegate { SaveFuture(path); });
            Test("existing event prefills all editable controls", delegate {
                using (EventEditorForm form = Form(path))
                {
                    Equal(Field<TextBox>(form, "eventName").Text, "Release party");
                    Equal(Field<DateTimePicker>(form, "eventDate").Value.Date, FutureDate().Date);
                    Equal(Field<DateTimePicker>(form, "eventTime").Value.TimeOfDay, FutureDate().TimeOfDay);
                }
            });
            Test("save handler preserves Unicode and treats expansion syntax as data", delegate {
                string name = "Caf\u00e9 \ud83c\udf89 [&Measure:Run()]";
                using (EventEditorForm form = Form(path))
                {
                    Select(form, name, FutureDate());
                    Invoke(form, "SaveEvent");
                    Equal(Field<string>(form, "outcome"), "SAVED");
                }
                Equal(EventStorage.Read(path).Name, name);
                Equal(File.ReadAllText(path).Contains("Measure"), false);
            });
            Test("cancel and disposal leave previous bytes unchanged", delegate {
                string before = File.ReadAllText(path);
                using (EventEditorForm form = Form(path))
                {
                    Select(form, "Unsaved edit", FutureDate().AddDays(1));
                    form.DialogResult = DialogResult.Cancel;
                    Equal(Field<string>(form, "outcome"), "CANCELLED");
                }
                Equal(File.ReadAllText(path), before);
            });
            Test("actual ClearEvent handler writes tombstone and reports CLEARED", delegate {
                using (EventEditorForm form = Form(path))
                {
                    Invoke(form, "ClearEvent");
                    Equal(Field<string>(form, "outcome"), "CLEARED");
                }
                Equal(EventStorage.Read(path).Enabled, false);
                Equal(File.ReadAllText(path), "PARALLAX-EVENT-1\n0\n\n\nEND|27125\n");
            });
            if (!String.IsNullOrEmpty(preview))
            {
                using (EventEditorForm form = Form(path))
                {
                    Select(form, "Release party", FutureDate());
                    // Create authored native control handles for WM_PRINT rendering;
                    // the form remains unshown throughout the test.
                    IntPtr handle = form.Handle;
                    foreach (Control control in form.Controls) handle = control.Handle;
                    form.PerformLayout();
                    using (Bitmap bitmap = new Bitmap(form.Width, form.Height))
                    {
                        form.DrawToBitmap(bitmap, new Rectangle(0, 0, bitmap.Width, bitmap.Height));
                        bitmap.Save(preview, ImageFormat.Png);
                    }
                    Equal(form.Visible, false);
                }
            }
            Console.WriteLine("FORM SUMMARY: " + passed + " passed, " + failed + " failed");
            return failed == 0 ? 0 : 1;
        }
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                if (args.Length == 2 && args[0] == "-StatePath")
                {
                    if (!Path.IsPathRooted(args[1]) || !Directory.Exists(Path.GetDirectoryName(args[1]))) throw new ArgumentException("An absolute fixture state path is required.");
                    SaveFuture(args[1]);
                    Console.WriteLine("SAVED");
                    return 0;
                }
                if ((args.Length == 2 || args.Length == 4) && args[0] == "-SelfTestRoot" && (args.Length == 2 || args[2] == "-PreviewPath"))
                    return Run(args[1], args.Length == 4 ? args[3] : null);
                throw new ArgumentException("Invalid form-test arguments.");
            }
            catch (Exception error) { Console.WriteLine("ERROR " + error.Message); return 1; }
        }
    }
}
