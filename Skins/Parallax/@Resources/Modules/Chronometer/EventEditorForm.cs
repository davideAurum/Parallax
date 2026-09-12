// Original Parallax event form. All entered text remains data, never a command.
using System;
using System.Drawing;
using System.Globalization;
using System.Windows.Forms;

namespace Parallax.Chronometer
{
    public sealed class EventEditorForm : Form
    {
        private readonly string statePath;
        private readonly TextBox eventName = new TextBox();
        private readonly DateTimePicker eventDate = new DateTimePicker();
        private readonly DateTimePicker eventTime = new DateTimePicker();
        private readonly Label status = new Label();
        private string outcome = "CANCELLED";

        private EventEditorForm(string path)
        {
            statePath = path;
            Text = "Chronometer event";
            AccessibleName = Text;
            ClientSize = new Size(480, 334);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Segoe UI", 9F);
            BackColor = Color.FromArgb(15, 15, 15);
            ForeColor = Color.FromArgb(220, 220, 220);

            Label title = MakeLabel("Event countdown", 20, 16, 440, 26);
            title.Font = new Font(Font.FontFamily, 13F, FontStyle.Bold);
            title.ForeColor = Color.FromArgb(137, 190, 250);
            MakeLabel("Event name", 20, 53, 440, 20);
            eventName.SetBounds(20, 77, 440, 25);
            eventName.MaxLength = 80;
            eventName.AccessibleName = "Event name";
            eventName.BackColor = Color.FromArgb(30, 30, 30);
            eventName.ForeColor = ForeColor;
            eventName.BorderStyle = BorderStyle.FixedSingle;
            eventName.TabIndex = 0;
            Controls.Add(eventName);

            MakeLabel("Date", 20, 117, 265, 20);
            MakeLabel("Time (24-hour)", 309, 117, 151, 20);
            eventDate.SetBounds(20, 141, 265, 25);
            eventDate.Format = DateTimePickerFormat.Custom;
            eventDate.CustomFormat = "yyyy-MM-dd";
            eventDate.MinDate = new DateTime(2000, 1, 1);
            eventDate.MaxDate = new DateTime(2099, 12, 31);
            eventDate.AccessibleName = "Event date";
            eventDate.TabIndex = 1;
            Controls.Add(eventDate);
            eventTime.SetBounds(309, 141, 151, 25);
            eventTime.Format = DateTimePickerFormat.Custom;
            eventTime.CustomFormat = "HH:mm";
            eventTime.ShowUpDown = true;
            eventTime.AccessibleName = "Event time";
            eventTime.TabIndex = 2;
            Controls.Add(eventTime);

            Label zone = MakeLabel("Time zone: " + TimeZoneInfo.Local.DisplayName, 20, 178, 440, 36);
            zone.ForeColor = Color.FromArgb(175, 175, 175);
            status.SetBounds(20, 220, 440, 51);
            status.ForeColor = Color.FromArgb(240, 225, 40);
            status.AccessibleName = "Event validation";
            Controls.Add(status);

            Button clear = MakeButton("Clear event", 20, 284, 112);
            clear.TabIndex = 5;
            clear.Click += delegate { ClearEvent(); };
            Button cancel = MakeButton("Cancel", 238, 284, 104);
            cancel.TabIndex = 4;
            cancel.DialogResult = DialogResult.Cancel;
            CancelButton = cancel;
            Button save = MakeButton("Save event", 354, 284, 106);
            save.TabIndex = 3;
            save.Click += delegate { SaveEvent(); };
            AcceptButton = save;

            DateTime initial = DateTime.Today.AddDays(1);
            if (initial < eventDate.MinDate) initial = eventDate.MinDate;
            if (initial > eventDate.MaxDate) initial = eventDate.MaxDate;
            try
            {
                EventData data = EventStorage.Read(path);
                if (data != null && data.Enabled)
                {
                    eventName.Text = data.Name;
                    initial = DateTimeOffset.FromUnixTimeSeconds(data.Deadline).LocalDateTime;
                }
            }
            catch
            {
                status.Text = "The saved event could not be read. Enter new details or clear it.";
            }
            if (initial.Date >= eventDate.MinDate.Date && initial.Date <= eventDate.MaxDate.Date)
                eventDate.Value = initial.Date;
            else
                status.Text = "The saved target is outside 2000-2099 in this time zone. Choose a new date.";
            eventTime.Value = initial;
            Shown += delegate { eventName.Focus(); eventName.SelectAll(); };
        }

        private Label MakeLabel(string text, int x, int y, int width, int height)
        {
            Label label = new Label();
            label.Text = text;
            label.SetBounds(x, y, width, height);
            Controls.Add(label);
            return label;
        }

        private Button MakeButton(string text, int x, int y, int width)
        {
            Button button = new Button();
            button.Text = text;
            button.AccessibleName = text;
            button.SetBounds(x, y, width, 30);
            button.FlatStyle = FlatStyle.Flat;
            button.BackColor = Color.FromArgb(30, 30, 30);
            button.ForeColor = Color.FromArgb(137, 190, 250);
            button.UseVisualStyleBackColor = false;
            Controls.Add(button);
            return button;
        }

        private void SaveEvent()
        {
            string name = eventName.Text.Trim();
            if (String.IsNullOrWhiteSpace(name))
            {
                status.Text = "Enter an event name.";
                eventName.Focus();
                return;
            }
            foreach (char character in name)
            {
                if (Char.IsControl(character))
                {
                    status.Text = "Use an event name without control characters.";
                    eventName.Focus();
                    return;
                }
            }
            DateTime local = DateTime.SpecifyKind(eventDate.Value.Date.AddHours(eventTime.Value.Hour)
                .AddMinutes(eventTime.Value.Minute), DateTimeKind.Unspecified);
            if (TimeZoneInfo.Local.IsInvalidTime(local))
            {
                status.Text = "That local time is skipped by daylight saving. Choose another time.";
                return;
            }
            if (TimeZoneInfo.Local.IsAmbiguousTime(local))
            {
                status.Text = "That time occurs twice when daylight saving ends. Choose an unambiguous time.";
                return;
            }
            try
            {
                EventData data = new EventData();
                data.Enabled = true;
                data.Name = name;
                data.LocalDate = local.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
                data.Deadline = new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(local)).ToUnixTimeSeconds();
                EventStorage.Write(statePath, data);
                outcome = "SAVED";
                DialogResult = DialogResult.OK;
                Close();
            }
            catch (ArgumentException)
            {
                status.Text = "Use a name of 1-80 characters without control characters, and a valid date.";
            }
            catch
            {
                status.Text = "Could not save the event. Check that its settings folder is writable.";
            }
        }

        private void ClearEvent()
        {
            try
            {
                EventStorage.Write(statePath, new EventData { Enabled = false, Deadline = 0, Name = "", LocalDate = "" });
                outcome = "CLEARED";
                DialogResult = DialogResult.OK;
                Close();
            }
            catch
            {
                status.Text = "Could not clear the event. Check that its settings folder is writable.";
            }
        }

        public static string ShowEditor(string path)
        {
            using (EventEditorForm dialog = new EventEditorForm(path))
            {
                dialog.ShowDialog();
                return dialog.outcome;
            }
        }
    }
}
