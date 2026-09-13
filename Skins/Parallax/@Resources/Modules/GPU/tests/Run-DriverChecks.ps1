#requires -Version 5.1
# Original native backend regressions. Uses in-memory fixture instrumentation;
# production source is never rewritten and no GPU/registry/settings data is changed.
# Run in a fresh Windows PowerShell 5.1 process, either x64 or x86.
# The bounded lifecycle fixture creates and removes only its random temp session.
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this native ABI suite in Windows PowerShell 5.1.' }
$gpuCheckOriginalDirectory = [Environment]::CurrentDirectory
$gpuCheckSourceDirectory = if ($PSScriptRoot) { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) } else { [Environment]::CurrentDirectory }
try {
[Environment]::CurrentDirectory = $gpuCheckSourceDirectory
$ErrorActionPreference='Stop'
$source=[IO.File]::ReadAllText('DriverTemperature.cs.txt')
$outer=@"
    public static string ProbeOnce(string luid)
    {
        using (Driver driver=new Driver(UInt64.Parse(luid,NumberStyles.AllowHexSpecifier,CultureInfo.InvariantCulture)))
        {
            string status=driver.Open();int? value=null;
            if(status=="OK")status=driver.ReadTemperature(out value);
            return "PROBE|"+status+"|"+(value.HasValue?value.ToString():"?")+"|"+driver.NameHex;
        }
    }
    public static string LifecycleFixture()
    {
        string luid="00000000000000AB";
        string token=CreateSession(luid,1000).Split('|')[2];Paths paths=new Paths(token);
        Exception failure=null;
        Driver.FixtureOpenStatus="UNSUPPORTED";Driver.FixtureOpened.Reset();
        Thread worker=new Thread(delegate(){try{Run(token,luid,1000);}catch(Exception error){failure=error;}});
        worker.IsBackground=true;
        try
        {
            WriteNew(paths.Lease,token+"|"+Number(Now()-14)+"|42|"+Number(GetCurrentProcessId()));
            worker.Start();
            if(!Driver.FixtureOpened.WaitOne(5000))throw new Exception("Helper did not open");
            Thread.Sleep(100);
            string[] sample=File.ReadAllText(paths.Data).Split('|');
            if(sample.Length!=27||sample[1]!="4"||sample[5]!="UNSUPPORTED"||sample[9]!="UNSUPPORTED"||sample[13]!="UNSUPPORTED"||sample[16]!="UNSUPPORTED"||Int64.Parse(sample[3])<1)throw new Exception("Terminal state was not observable");
            if(sample[25]!="42"||!sample[26].StartsWith(Number(GetCurrentProcessId())+","))throw new Exception("Process lookup depends on GPU support or request ID was lost");
            File.WriteAllText(paths.Lease,token+"|"+Number(Now()-100),Ascii);
            if(!worker.Join(4000))throw new Exception("Unrenewed lease did not stop helper");
            if(failure!=null)throw failure;
            if(File.Exists(paths.Data)||File.Exists(paths.Lease)||File.Exists(paths.Temporary))throw new Exception("Session files remain");
            return "PASS: one-host terminal-state publication, original lease expiry and session cleanup";
        }
        finally{Driver.FixtureOpenStatus=null;Delete(paths.Data);Delete(paths.Lease);Delete(paths.Temporary);}
    }
    public static string PureFixtures()
    {
        int count=0;Action<bool,string> check=delegate(bool ok,string label){++count;if(!ok)throw new Exception(label);};
        string token="0123456789abcdef0123456789abcdef",luid="00000000000000AB";long stamp;
        check(ParseLease(token+"|1000",token,1000,1000,out stamp)&&stamp==1000,"fresh");
        check(ParseLease(token+"|985",token,1000,1000,out stamp),"age15");
        check(!ParseLease(token+"|984",token,1000,1000,out stamp),"age16");
        check(ParseLease(token+"|910",token,1000,30000,out stamp),"age90");
        check(!ParseLease(token+"|909",token,1000,30000,out stamp),"age91");
        check(ParseLease(token+"|1005",token,1000,1000,out stamp),"future5");
        check(!ParseLease(token+"|1006",token,1000,1000,out stamp),"future6");
        foreach(string bad in new string[]{"",token+"|",token+"|01",token+"|-1",token+"|1e3",token+"|1000\n",token+"|999999999999",new string('f',32)+"|1000",token+"|1000|x"})
            check(!ParseLease(bad,token,1000,1000,out stamp),"invalid lease");
        check(!LeaseFresh(1000,1016,1000),"cache never renews");check(!LeaseFresh(1000,900,1000),"clock rollback");
        foreach(string bad in new string[]{"",new string('a',31),new string('a',33),"../"+new string('a',29),new string('g',32)})
        {bool threw=false;try{ValidateToken(bad);}catch(ArgumentException){threw=true;}check(threw,"bad token");}
        foreach(int bad in new int[]{-1,0,999,30001,Int32.MaxValue})
        {bool threw=false;try{ValidateInterval(bad);}catch(ArgumentOutOfRangeException){threw=true;}check(threw,"bad interval");}
        string sample=Snapshot(token,1,1000,"OK",49,luid,"?");
        check(sample.Split('|').Length==27,"27 fields");check(sample.Split('|')[6]=="49","Celsius");
        check(sample.Split('|')[7]==luid,"LUID");
        check(Snapshot(token,0,1000,"STARTING",null,luid,"?").Split('|')[6]=="?","starting");
        check(Snapshot(token,2,1001,"DEVICE_CHANGED",49,luid,"?").Split('|')[6]=="?","no old reading");
        check(Snapshot(token,2,1001,"UNAVAILABLE",null,luid,new string('A',2049)).Split('|')[8]=="?","bounded name");
        foreach(int value in new int[]{-274,301})
        {bool threw=false;try{Snapshot(token,1,1000,"OK",value,luid,"?");}catch(InvalidOperationException){threw=true;}check(threw,"temp range");}
        foreach(int value in new int[]{-273,0,300})check(Snapshot(token,1,1000,"OK",value,luid,"?").Split('|')[6]==Number(value),"range endpoint");
        bool overflow=false;try{Snapshot(token,MaximumSequence+1,1000,"OK",49,luid,"?");}catch(InvalidOperationException){overflow=true;}
        check(overflow,"sequence bound");
        string generated=CreateSession(luid,1000).Split('|')[2];Paths paths=new Paths(generated);
        check(!File.Exists(paths.Data)&&!File.Exists(paths.Lease)&&!File.Exists(paths.Temporary),"bootstrap creates no files");
        check(Path.GetFileName(paths.Data)=="Parallax-GPU-"+generated+".dat","basename");
        check(paths.Lease==paths.Data.Substring(0,paths.Data.Length-4)+".lease","lease sibling");
        check(paths.Temporary==paths.Data.Substring(0,paths.Data.Length-4)+".tmp","tmp sibling");
        try
        {
            Run(generated,luid,1000);check(Driver.FixtureOpenCalls==0&&!File.Exists(paths.Data),"missing lease blocks init");
            WriteNew(paths.Lease,generated+"|"+Number(Now()-100));
            Run(generated,luid,1000);check(Driver.FixtureOpenCalls==0&&!File.Exists(paths.Data),"expired lease blocks init");
            WriteSnapshot(paths,Snapshot(generated,0,Now(),"STARTING",null,luid,"?"),true);
            WriteSnapshot(paths,Snapshot(generated,1,Now(),"OK",42,luid,"?"),false);
            check(File.ReadAllText(paths.Data).Split('|')[3]=="1","atomic next sequence");
            check(!File.Exists(paths.Temporary),"tmp moved");
            using(FileStream reader=new FileStream(paths.Data,FileMode.Open,FileAccess.Read,FileShare.Read))
            {
                bool blocked=false;
                try{WriteSnapshot(paths,Snapshot(generated,2,Now(),"OK",43,luid,"?"),false);}
                catch(IOException){blocked=true;}catch(UnauthorizedAccessException){blocked=true;}
                check(blocked,"reader sharing blocks replacement");
                check(File.ReadAllText(paths.Data).Split('|')[3]=="1","blocked publication preserves prior sample");
                check(!File.Exists(paths.Temporary),"blocked publication cleans tmp");
            }
            WriteSnapshot(paths,Snapshot(generated,3,Now(),"OK",44,luid,"?"),false);
            check(File.ReadAllText(paths.Data).Split('|')[3]=="3","publication recovers after reader closes");
        }
        finally{Delete(paths.Data);Delete(paths.Lease);Delete(paths.Temporary);}
        count+=ProcessNameFixtures();count+=Driver.ThermalFixtures();
        count+=Driver.MemoryFixtures();count+=Driver.PowerClockFixtures();
        Frame frame=new Frame("OK");frame.Temperature=0;frame.Physical=8192;frame.Allocatable=8000;frame.Available=0;
        frame.SharedCommitted=0;frame.SharedResident=1;frame.Utilization[0]=0;frame.Utilization[2]=100;frame.PowerMilliwatts=13299;frame.GraphicsClockKHz=607500;
        string[] fields=Snapshot(token,3,1002,frame,luid,"?").Split('|');
        check(fields.Length==27&&fields[1]=="4","extended protocol version");
        check(fields[10]=="8192"&&fields[11]=="8000"&&fields[12]=="0","memory protocol bytes");
        check(fields[14]=="0"&&fields[15]=="1","shared zero and independent resident");
        check(fields[17]=="0"&&fields[18]=="?"&&fields[19]=="100"&&fields[20]=="?","per-domain availability");
        check(fields[21]=="OK"&&fields[22]=="13299"&&fields[23]=="OK"&&fields[24]=="607500","power mW and current clock kHz positions");
        foreach(string feature in new string[]{"thermal","memory","shared","utilization","power","clock"})
        {
            frame.TemperatureStatus=frame.MemoryStatus=frame.SharedStatus=frame.UtilizationStatus=frame.PowerStatus=frame.ClockStatus="OK";
            if(feature=="thermal")frame.TemperatureStatus="DEVICE_CHANGED";
            if(feature=="memory")frame.MemoryStatus="DEVICE_CHANGED";
            if(feature=="shared")frame.SharedStatus="DEVICE_CHANGED";
            if(feature=="utilization")frame.UtilizationStatus="DEVICE_CHANGED";
            if(feature=="power")frame.PowerStatus="DEVICE_CHANGED";
            if(feature=="clock")frame.ClockStatus="DEVICE_CHANGED";
            fields=Snapshot(token,3,1002,frame,luid,"?").Split('|');
            check(fields[5]=="DEVICE_CHANGED"&&fields[9]=="DEVICE_CHANGED"&&fields[13]=="DEVICE_CHANGED"&&fields[16]=="DEVICE_CHANGED","whole frame status invalidation");
            check(fields[6]=="?"&&fields[10]=="?"&&fields[11]=="?"&&fields[12]=="?"&&fields[14]=="?"&&fields[15]=="?"&&fields[17]=="?"&&fields[18]=="?"&&fields[19]=="?"&&fields[20]=="?","whole frame reading invalidation");
            check(fields[21]=="DEVICE_CHANGED"&&fields[22]=="?"&&fields[23]=="DEVICE_CHANGED"&&fields[24]=="?","power and clock invalidate with frame");
        }
        frame.TemperatureStatus=frame.MemoryStatus=frame.SharedStatus=frame.UtilizationStatus=frame.PowerStatus=frame.ClockStatus="OK";
        frame.SharedCommitted=(ulong)MaximumSequence+1;
        bool byteOverflow=false;try{Snapshot(token,3,1002,frame,luid,"?");}catch(InvalidOperationException){byteOverflow=true;}
        check(byteOverflow,"snapshot rejects lossy shared integer");frame.SharedCommitted=0;
        frame.Allocatable=0;bool partial=false;try{Snapshot(token,3,1002,frame,luid,"?");}catch(InvalidOperationException){partial=true;}
        check(partial,"snapshot rejects partial framebuffer");frame.Allocatable=8000;
        frame.Utilization[0]=101;bool badPercent=false;try{Snapshot(token,3,1002,frame,luid,"?");}catch(InvalidOperationException){badPercent=true;}
        check(badPercent,"snapshot rejects percentage overflow");
        frame.Utilization[0]=0;frame.GraphicsClockKHz=0;
        bool zeroClock=false;try{Snapshot(token,3,1002,frame,luid,"?");}catch(InvalidOperationException){zeroClock=true;}
        check(zeroClock,"snapshot rejects zero current clock");frame.GraphicsClockKHz=607500;
        frame.PowerMilliwatts=0;check(Snapshot(token,3,1002,frame,luid,"?").Split('|')[22]=="0","measured zero power survives");
        return "PASS: "+count+" lease, process-name, bounds, snapshot, thermal, memory, activity, power and clock identity assertions";
    }

    public static string OwnProcessNameProbe()
    {
        uint pid=GetCurrentProcessId();
        using(ProcessNames resolver=new ProcessNames())
        using(System.Diagnostics.Process self=System.Diagnostics.Process.GetCurrentProcess())
        {
            string result=resolver.Read(new uint[]{pid});
            string expected=Number(pid)+","+ProcessNameHex(self.ProcessName);
            if(result!=expected||!ValidProcessMap(result))throw new Exception("Own-PID basename lookup failed");
            if(resolver.Read(new uint[]{pid})!=expected)throw new Exception("Retained own-PID lookup changed");
            if(resolver.Read(new uint[0])!="?")throw new Exception("Empty request retained own-PID name");
            return "PASS: native own-PID basename lookup and retained-handle reuse ("+self.ProcessName+")";
        }
    }

    private static int ProcessNameFixtures()
    {
        int count=0;Action<bool,string> check=delegate(bool ok,string label){++count;if(!ok)throw new Exception(label);};
        string token="0123456789abcdef0123456789abcdef",luid="00000000000000AB";Lease lease;
        check(ParseLease(token+"|1000",token,1000,1000,out lease)&&lease.Timestamp==1000&&lease.RequestId==0&&lease.ProcessIds.Length==0,"legacy lease resets names");
        check(ParseLease(token+"|1000|0|?",token,1000,1000,out lease)&&lease.RequestId==0&&lease.ProcessIds.Length==0,"explicit empty request");
        check(ParseLease(token+"|1000|9007199254740991|1,2,3,4,4294967295",token,1000,1000,out lease)&&lease.RequestId==MaximumSequence&&lease.ProcessIds.Length==5&&lease.ProcessIds[4]==UInt32.MaxValue,"request and PID endpoints");
        foreach(string bad in new string[]{"|?","-1|?","01|?","1.0|?","1e3|?","9007199254740992|?","42|","42|0","42|01","42|-1","42|1,1","42|1,2,3,4,5,6","42|1,","42|4294967296","42|1 2","42|1|2","42|?\n","42|1;2","42|1,?"})
            check(!ParseLease(token+"|1000|"+bad,token,1000,1000,out lease)&&lease==null,"reject malformed request without heartbeat renewal");
        string generated=CreateSession(luid,1000).Split('|')[2];Paths paths=new Paths(generated);
        try
        {
            WriteNew(paths.Lease,generated+"|1000|7|1,2");
            check(ReadLease(paths.Lease,generated,1000,1000,out lease)&&lease.RequestId==7,"read extended lease");
            Lease retained=lease;
            File.WriteAllText(paths.Lease,generated+"|1001|8|1,1",Ascii);
            if(ReadLease(paths.Lease,generated,1001,1000,out lease))retained=lease;
            check(retained.RequestId==7&&retained.Timestamp==1000&&retained.ProcessIds.Length==2,"invalid write preserves entire last valid request");
            File.WriteAllText(paths.Lease,generated+"|1002|8|2",Ascii);
            check(ReadLease(paths.Lease,generated,1002,1000,out lease)&&lease.RequestId==8&&lease.ProcessIds.Length==1&&lease.ProcessIds[0]==2,"new generation replaces complete request");
            File.WriteAllText(paths.Lease,new string('a',129),Ascii);
            check(!ReadLease(paths.Lease,generated,1002,1000,out lease),"bounded lease read");
            File.WriteAllBytes(paths.Lease,new byte[]{255});
            check(!ReadLease(paths.Lease,generated,1002,1000,out lease),"ASCII lease only");
        }
        finally{Delete(paths.Lease);}
        check(ProcessNameHex(new string('a',128)).Length==256&&ProcessNameHex(new string('a',129))==null,"basename byte bound");
        check(ProcessNameHex(new string('\u00e9',64)).Length==256&&ProcessNameHex(new string('\u00e9',65))==null,"UTF8 byte rather than character bound");
        foreach(string bad in new string[]{null,"",".","..","C:\\secret\\app","folder/app","app\nname",new string('\ud800',1)})
            check(ProcessNameHex(bad)==null,"invalid basename rejected");
        check(ProcessNameHex("app#[];")=="617070235B5D3B","delimiter characters are hex data");
        foreach(string bad in new string[]{null,"","0,61","01,61","1,","1,0","1,GG","1,FF","1,C0AF","1,00","1,5C","1,2F","1,61;1,62","1,61;2,61;3,61;4,61;5,61;6,61","1,"+new string('A',258),"4294967296,61"})
            check(!ValidProcessMap(bad),"invalid map rejected");
        check(ValidProcessMap("?")&&ValidProcessMap("1,61;4294967295,C3A9"),"valid bounded maps");
        string longest="4294967295,"+new string('6',256)+";4294967294,"+new string('6',256)+";4294967293,"+new string('6',256)+";4294967292,"+new string('6',256)+";4294967291,"+new string('6',256);
        Frame frame=new Frame("DEVICE_CHANGED");
        string sample=Snapshot(token,MaximumSequence,253402300799L,frame,luid,new string('6',2048),MaximumSequence,longest);
        check(sample.Length<=4096&&sample.Split('|').Length==27&&sample.Split('|')[25]==Number(MaximumSequence)&&sample.Split('|')[26]==longest,"maximum map bounded and independent of changed GPU");
        foreach(long invalid in new long[]{-1,MaximumSequence+1})
        {bool threw=false;try{Snapshot(token,1,1000,frame,luid,"?",invalid,"?");}catch(InvalidOperationException){threw=true;}check(threw,"invalid response generation");}
        bool invalidMap=false;try{Snapshot(token,1,1000,frame,luid,"?",1,"1,FF");}catch(InvalidOperationException){invalidMap=true;}check(invalidMap,"invalid map cannot publish");
        int opens=0,queries=0,closes=0,live=0,peak=0;bool running=true,denied=false,queryFailure=false;string name="example";Queue<bool> life=null;
        Func<uint,IntPtr> open=delegate(uint pid){++opens;if(denied)return IntPtr.Zero;++live;peak=Math.Max(peak,live);return new IntPtr(pid);};
        Func<IntPtr,bool> alive=delegate(IntPtr handle){return life!=null?life.Dequeue():running;};
        Func<IntPtr,string> query=delegate(IntPtr handle){++queries;if(queryFailure)throw new IOException();return name;};
        Action<IntPtr> close=delegate(IntPtr handle){++closes;--live;};
        ProcessNames resolver=new ProcessNames(open,alive,query,close);
        check(resolver.Read(new uint[]{1,2,3,4,5}).Split(';').Length==5&&opens==5&&queries==5&&live==5,"bounded first lookups");
        check(resolver.Read(new uint[]{5,4,3,2,1}).StartsWith("5,")&&opens==5&&queries==5,"rank order change retains process identities");
        check(resolver.Read(new uint[]{6,7,8,9,10}).Split(';').Length==5&&opens==10&&closes==5&&live==5&&peak==5,"close dropped handles before opening replacements");
        running=false;check(resolver.Read(new uint[]{6})=="?"&&live==0,"exited PID clears name and closes handle");
        running=true;name="reused";check(resolver.Read(new uint[]{6})=="?"&&opens==10,"never reopen continuously requested dead PID");
        check(resolver.Read(new uint[0])=="?","empty set drops failed entry");
        check(resolver.Read(new uint[]{6})=="6,726575736564"&&opens==11,"PID may resolve only after leaving request set");
        resolver.Read(new uint[0]);denied=true;
        check(resolver.Read(new uint[]{7})=="?"&&opens==12,"denied process falls back");denied=false;
        check(resolver.Read(new uint[]{7})=="?"&&opens==12,"denied process not retried while requested");
        resolver.Read(new uint[0]);life=new Queue<bool>(new bool[]{true,false});
        check(resolver.Read(new uint[]{8})=="?"&&live==0,"exit during lookup invalidates name");life=null;
        resolver.Read(new uint[0]);queryFailure=true;
        check(resolver.Read(new uint[]{9})=="?"&&live==0,"query exception closes process handle");queryFailure=false;
        resolver.Read(new uint[0]);name=null;
        check(resolver.Read(new uint[]{10})=="?"&&live==0,"missing basename closes process handle");name="example";
        resolver.Read(new uint[]{1,2});int stableOpens=opens;
        foreach(uint[] invalid in new uint[][]{null,new uint[]{0},new uint[]{1,1},new uint[]{1,2,3,4,5,6}})
        {bool threw=false;try{resolver.Read(invalid);}catch(ArgumentException){threw=true;}check(threw&&opens==stableOpens&&live==2,"invalid request causes no lookup or mutation");}
        resolver.Dispose();int stableCloses=closes;resolver.Dispose();
        check(live==0&&closes==stableCloses&&resolver.Read(new uint[]{1})=="?"&&opens==stableOpens,"idempotent cleanup and no work after disposal");
        return count;
    }
"@
$inner=@"
        internal static int FixtureOpenCalls;
        internal static string FixtureOpenStatus;
        internal static ManualResetEvent FixtureOpened=new ManualResetEvent(false);
        internal static Queue<bool> FixtureIdentity;
        internal static int ThermalFixtures()
        {
            int count=0,calls=0;Action<bool,string> check=delegate(bool ok,string label){++count;if(!ok)throw new Exception(label);};
            Driver driver=new Driver(1);driver.opened=true;driver.nvidiaStatus="OK";int status=0,value=49,target=1,sensorCount=1;
            driver.thermal=delegate(IntPtr gpu,uint index,ref ThermalSettings data)
            {
                ++calls;check(index==15,"all sensors");check(data.Version==(68|0x20000),"V2");
                data.Count=(uint)sensorCount;data.Sensors[0].CurrentTemp=value;data.Sensors[0].Target=target;
                data.Sensors[1].CurrentTemp=value;data.Sensors[1].Target=target;return status;
            };
            int? result;
            FixtureIdentity=new Queue<bool>(new bool[]{false});
            check(driver.ReadTemperature(out result)=="DEVICE_CHANGED"&&!result.HasValue&&calls==0,"before identity blocks call");
            FixtureIdentity=new Queue<bool>(new bool[]{true,false});
            check(driver.ReadTemperature(out result)=="DEVICE_CHANGED"&&!result.HasValue&&calls==1,"after identity clears result");
            foreach(int t in new int[]{-273,0,49,300})
            {value=t;FixtureIdentity=new Queue<bool>(new bool[]{true,true});check(driver.ReadTemperature(out result)=="OK"&&result==value,"GPU target");}
            foreach(int t in new int[]{-274,301})
            {value=t;FixtureIdentity=new Queue<bool>(new bool[]{true,true});check(driver.ReadTemperature(out result)=="UNAVAILABLE"&&!result.HasValue,"invalid temperature");}
            value=49;target=2;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNSUPPORTED"&&!result.HasValue,"memory not GPU");
            target=1;sensorCount=2;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNSUPPORTED"&&!result.HasValue,"ambiguous sensors");
            sensorCount=4;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNAVAILABLE"&&!result.HasValue,"bounded sensors");
            sensorCount=1;status=-104;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNSUPPORTED"&&!result.HasValue,"unsupported");
            status=-9;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNSUPPORTED"&&!result.HasValue,"wrong ABI");
            status=-1;FixtureIdentity=new Queue<bool>(new bool[]{true,true});
            check(driver.ReadTemperature(out result)=="UNAVAILABLE"&&!result.HasValue,"query failed");
            FixtureIdentity=null;driver.Dispose();driver.Dispose();
            check(driver.ReadTemperature(out result)=="UNAVAILABLE"&&!result.HasValue,"disposed");
            check(Marshal.SizeOf(typeof(ThermalSensor))==20&&Marshal.SizeOf(typeof(ThermalSettings))==68,"thermal ABI");
            check(Marshal.SizeOf(typeof(LogicalData))==(IntPtr.Size==8?568:300),"logical ABI");
            return count;
        }

        internal static int PowerClockFixtures()
        {
            int count=0,clockCalls=0,powerCalls=0;
            Action<bool,string> check=delegate(bool ok,string label){++count;if(!ok)throw new Exception(label);};
            Action resetIdentity=delegate(){FixtureIdentity=new Queue<bool>();for(int i=0;i<96;++i)FixtureIdentity.Enqueue(true);};
            Driver driver=new Driver(1);driver.opened=true;driver.nvidiaStatus="OK";driver.physical=new IntPtr(1);
            uint frequency=607500,present=1,selector=0;
            int clockStatus=0,v2Status=0;bool badClockVersion=false;
            driver.clocks=delegate(IntPtr gpu,ref ClockData data)
            {
                ++clockCalls;uint version=data.Version>>16;
                check((version==3||version==2)&&(data.Version&65535)==264&&data.ClockType==0&&data.Domains.Length==32,"current clock ABI and selector");
                data.ClockType=0xff000000|selector;data.Domains[0].Present=present;data.Domains[0].FrequencyKHz=frequency;
                if(badClockVersion)data.Version=0;return version==3?clockStatus:v2Status;
            };
            uint? scalar;resetIdentity();
            check(driver.ReadClock(out scalar)=="OK"&&scalar==607500,"current clock preserves fractional MHz as integer kHz");
            clockStatus=-9;resetIdentity();int before=clockCalls;
            check(driver.ReadClock(out scalar)=="OK"&&scalar==607500&&clockCalls==before+2,"V3 incompatible falls back to V2 current");
            v2Status=-9;resetIdentity();check(driver.ReadClock(out scalar)=="UNSUPPORTED"&&!scalar.HasValue,"no V1 clock fallback");
            v2Status=0;
            foreach(int error in new int[]{-104,-1,-10})
            {clockStatus=error;resetIdentity();before=clockCalls;check(driver.ReadClock(out scalar)==(error==-104?"UNSUPPORTED":error==-10?"DEVICE_CHANGED":"UNAVAILABLE")&&!scalar.HasValue&&clockCalls==before+1,"clock failures do not change selector or fallback");}
            clockStatus=0;frequency=0;resetIdentity();check(driver.ReadClock(out scalar)=="UNAVAILABLE"&&!scalar.HasValue,"zero clock is unusable");frequency=607500;
            present=2;resetIdentity();check(driver.ReadClock(out scalar)=="UNSUPPORTED"&&!scalar.HasValue,"absent graphics clock mask");present=3;
            resetIdentity();check(driver.ReadClock(out scalar)=="OK"&&scalar==frequency,"clock present bit accepts reserved flags");
            foreach(uint wrong in new uint[]{1,2,15}){selector=wrong;resetIdentity();check(driver.ReadClock(out scalar)=="UNAVAILABLE"&&!scalar.HasValue,"base or boost never mistaken for current");}
            selector=0;badClockVersion=true;resetIdentity();check(driver.ReadClock(out scalar)=="UNAVAILABLE","returned clock version validated");badClockVersion=false;
            FixtureIdentity=new Queue<bool>(new bool[]{false});before=clockCalls;
            check(driver.ReadClock(out scalar)=="DEVICE_CHANGED"&&clockCalls==before,"clock identity checked before query");
            FixtureIdentity=new Queue<bool>(new bool[]{true,false});
            check(driver.ReadClock(out scalar)=="DEVICE_CHANGED"&&!scalar.HasValue,"clock identity checked after query");
            NvidiaClockQuery savedClocks=driver.clocks;driver.clocks=null;resetIdentity();
            check(driver.ReadClock(out scalar)=="UNSUPPORTED","missing clock API");driver.clocks=savedClocks;

            uint inventoryCount=2,nvmlCount=2,bus=1,domain=0,function=0,mw=13299;
            int inventoryStatus=0,nvmlCountStatus=0,nvmlHandleStatus=0,nvmlPciStatus=0,powerStatus=0,pciStatus=0;
            bool nvidiaCollision=false,nvmlCollision=false,duplicateNvidia=false,duplicateNvml=false,badBusId=false,mutatePci=false,mutateDomain=false;
            driver.pciBus=delegate(IntPtr gpu,out uint value){value=gpu==new IntPtr(1)?bus:nvidiaCollision?bus:2u;return pciStatus;};
            driver.pciSlot=delegate(IntPtr gpu,out uint value){value=0;return 0;};
            driver.pciIdentifiers=delegate(IntPtr gpu,out uint device,out uint subsystem,out uint revision,out uint external)
            {device=0x1b8010de;subsystem=0x33661028;revision=0xa1;external=0x1b80;return 0;};
            driver.physicalInventory=delegate(IntPtr[] handles,out uint devices)
            {devices=inventoryCount;handles[0]=new IntPtr(1);handles[1]=new IntPtr(duplicateNvidia?1:2);return inventoryStatus;};
            check(driver.MatchNvidiaPowerInventory()=="OK","selected PCI tuple unique across complete NVAPI inventory");
            nvidiaCollision=true;check(driver.MatchNvidiaPowerInventory()=="UNSUPPORTED","NVAPI same tuple collision rejected even if other GPU absent from NVML");nvidiaCollision=false;
            duplicateNvidia=true;check(driver.MatchNvidiaPowerInventory()=="UNAVAILABLE","duplicate physical handle rejected");duplicateNvidia=false;
            foreach(uint invalid in new uint[]{0,65}){inventoryCount=invalid;check(driver.MatchNvidiaPowerInventory()=="UNAVAILABLE","bounded complete NVAPI inventory");}inventoryCount=2;
            inventoryStatus=-1;check(driver.MatchNvidiaPowerInventory()=="UNAVAILABLE","NVAPI inventory error not ignored");inventoryStatus=0;
            pciStatus=-1;check(driver.MatchNvidiaPowerInventory()=="UNAVAILABLE","unreadable PCI tuple not ignored");pciStatus=0;
            check(driver.MatchNvidiaPowerInventory()=="OK","PCI identity recovers in isolated fixture");
            NvmlCount getCount=delegate(out uint devices){devices=nvmlCount;return nvmlCountStatus;};
            NvmlHandle getHandle=delegate(uint index,out IntPtr device){device=new IntPtr(20+(duplicateNvml?0:(int)index));return index==1?nvmlHandleStatus:0;};
            driver.nvmlPci=delegate(IntPtr device,ref NvmlPci data)
            {
                data.Domain=domain;data.Bus=device==new IntPtr(20)?1u:nvmlCollision?1u:2u;data.Slot=0;data.Device=0x1b8010de;data.Subsystem=0x33661028;
                string id=badBusId?"00000000:FF:00.0":data.Domain.ToString("X8")+":"+data.Bus.ToString("X2")+":00."+function.ToString();
                byte[] encoded=Encoding.ASCII.GetBytes(id);Array.Copy(encoded,data.BusId,encoded.Length);return nvmlPciStatus;
            };
            driver.nvmlPower=delegate(IntPtr device,out uint value)
            {++powerCalls;check(device==new IntPtr(20),"bound NVML power handle");value=mw;if(mutatePci)bus=2;if(mutateDomain)domain=1;return powerStatus;};
            resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="OK"&&driver.nvmlDevice==new IntPtr(20),"unique complete NVML match");
            nvmlCollision=true;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNSUPPORTED","NVML duplicate tuple rejected");nvmlCollision=false;
            duplicateNvml=true;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNAVAILABLE","duplicate NVML handle rejected");duplicateNvml=false;
            nvmlHandleStatus=4;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNAVAILABLE","unreadable later NVML device rejects earlier candidate");nvmlHandleStatus=0;
            foreach(uint invalid in new uint[]{0,65}){nvmlCount=invalid;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNAVAILABLE","bounded complete NVML inventory");}nvmlCount=2;
            nvmlCountStatus=999;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNAVAILABLE","NVML count error");nvmlCountStatus=0;
            nvmlPciStatus=3;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNSUPPORTED","missing NVML PCI support");nvmlPciStatus=0;
            badBusId=true;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNAVAILABLE","PCI string and numeric fields must agree");badBusId=false;
            function=1;resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="UNSUPPORTED","nonzero PCI function not guessed");function=0;
            resetIdentity();check(driver.MatchNvmlPowerInventory(getCount,getHandle)=="OK","power binding fixture restored");driver.powerSupport="OK";
            foreach(uint value in new uint[]{0,13299,UInt32.MaxValue})
            {mw=value;resetIdentity();check(driver.ReadPower(out scalar)=="OK"&&scalar==value,"native mW returned exactly, including zero");}
            foreach(int error in new int[]{3,4,15,999})
            {powerStatus=error;resetIdentity();check(driver.ReadPower(out scalar)==(error==3?"UNSUPPORTED":error==15?"DEVICE_CHANGED":"UNAVAILABLE")&&!scalar.HasValue,"NVML power error status");}
            powerStatus=0;mw=13299;mutatePci=true;resetIdentity();
            check(driver.ReadPower(out scalar)=="DEVICE_CHANGED"&&!scalar.HasValue,"PCI mutation after power clears reading");mutatePci=false;bus=1;
            mutateDomain=true;resetIdentity();check(driver.ReadPower(out scalar)=="DEVICE_CHANGED"&&!scalar.HasValue,"NVML domain mutation after power clears reading");mutateDomain=false;domain=0;
            FixtureIdentity=new Queue<bool>(new bool[]{false});before=powerCalls;
            check(driver.ReadPower(out scalar)=="DEVICE_CHANGED"&&powerCalls==before,"power identity before query");
            driver.powerSupport="UNSUPPORTED";resetIdentity();check(driver.ReadPower(out scalar)=="UNSUPPORTED"&&!scalar.HasValue,"missing NVML power provider");
            resetIdentity();Frame combined=driver.ReadFrame();
            check(combined.ClockStatus=="OK"&&combined.PowerStatus=="UNSUPPORTED","missing power preserves clock");
            driver.powerSupport="OK";driver.clocks=null;resetIdentity();combined=driver.ReadFrame();
            check(combined.PowerStatus=="OK"&&combined.PowerMilliwatts==13299&&combined.ClockStatus=="UNSUPPORTED","missing clock preserves power");
            driver.clocks=savedClocks;clockStatus=-10;resetIdentity();combined=driver.ReadFrame();
            check(combined.PowerStatus=="DEVICE_CHANGED"&&!combined.PowerMilliwatts.HasValue&&combined.ClockStatus=="DEVICE_CHANGED","late clock identity failure invalidates power frame");
            clockStatus=0;powerStatus=15;resetIdentity();combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="DEVICE_CHANGED"&&combined.PowerStatus=="DEVICE_CHANGED"&&combined.ClockStatus=="DEVICE_CHANGED","lost NVML GPU invalidates whole frame");
            int shutdowns=0;driver.nvmlInitialized=true;driver.nvmlShutdown=delegate(){++shutdowns;return 0;};
            FixtureIdentity=null;driver.Dispose();driver.Dispose();check(shutdowns==1&&!driver.nvmlInitialized,"NVML shutdown exactly once");
            check(driver.ReadPower(out scalar)=="UNAVAILABLE"&&!scalar.HasValue&&driver.ReadClock(out scalar)=="UNAVAILABLE","disposed scalar readings");
            check(Marshal.SizeOf(typeof(ClockData))==264&&Marshal.SizeOf(typeof(ClockDomain))==8,"clock ABI size");
            check(Marshal.SizeOf(typeof(NvmlPci))==68&&Marshal.OffsetOf(typeof(NvmlPci),"Domain").ToInt32()==16&&Marshal.OffsetOf(typeof(NvmlPci),"BusId").ToInt32()==36,"NVML PCI ABI size and offsets");
            return count;
        }

        internal static int MemoryFixtures()
        {
            int count=0,exCalls=0,legacyCalls=0,sharedCalls=0,utilCalls=0;
            Action<bool,string> check=delegate(bool ok,string label){++count;if(!ok)throw new Exception(label);};
            Action resetIdentity=delegate(){FixtureIdentity=new Queue<bool>();for(int i=0;i<64;++i)FixtureIdentity.Enqueue(true);};
            Driver driver=new Driver(1);driver.opened=true;driver.nvidiaStatus="OK";
            int exStatus=0,legacyStatus=0,queryStatus=0,propertyStatus=0,utilStatus=0;
            uint physicalCount=1,mask=15,percent=0;
            ulong physicalBytes=8589934592,allocatableBytes=8450473984,availableBytes=6000000000,committed=0,resident=1;
            bool badVersion=false,badUtilVersion=false;
            NvidiaMemoryExQuery ex=delegate(IntPtr gpu,ref MemoryEx data)
            {
                ++exCalls;check(data.Version==(80|0x10000),"memory EX ABI version");
                data.Physical=physicalBytes;data.Allocatable=allocatableBytes;data.Available=availableBytes;
                data.SharedLimit=UInt64.MaxValue;if(badVersion)data.Version=0;return exStatus;
            };
            NvidiaMemoryQuery legacy=delegate(IntPtr gpu,ref MemoryLegacy data)
            {
                ++legacyCalls;check(data.Version==(32|0x30000),"legacy ABI version");
                data.Physical=8388608;data.Allocatable=8252416;data.Available=6318392;return legacyStatus;
            };
            driver.memoryEx=ex;driver.memoryLegacy=legacy;
            Frame frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadMemory(frame)=="OK"&&frame.Physical==physicalBytes&&frame.Available==availableBytes&&legacyCalls==0,"prefer EX bytes");
            check(!frame.SharedCommitted.HasValue&&!frame.SharedResident.HasValue,"shared limit is never usage");
            foreach(int unsupported in new int[]{-3,-9,-104,-136})
            {
                exStatus=unsupported;frame=new Frame("UNAVAILABLE");resetIdentity();int before=legacyCalls;
                check(driver.ReadMemory(frame)=="OK"&&legacyCalls==before+1&&frame.Physical==8589934592&&frame.Available==6470033408,"unsupported EX uses widened legacy KB");
            }
            exStatus=-1;frame=new Frame("UNAVAILABLE");resetIdentity();int legacyBefore=legacyCalls;
            check(driver.ReadMemory(frame)=="UNAVAILABLE"&&!frame.Physical.HasValue&&legacyCalls==legacyBefore,"ordinary failure does not mask with fallback");
            exStatus=-10;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadMemory(frame)=="DEVICE_CHANGED"&&!frame.Physical.HasValue&&legacyCalls==legacyBefore,"invalidated memory handle");
            exStatus=0;driver.memoryEx=null;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadMemory(frame)=="OK"&&frame.Physical==8589934592,"missing EX uses legacy");
            driver.memoryLegacy=null;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadMemory(frame)=="UNSUPPORTED"&&!frame.Physical.HasValue,"missing memory APIs");
            driver.memoryEx=ex;driver.memoryLegacy=legacy;
            badVersion=true;frame=new Frame("UNAVAILABLE");resetIdentity();legacyBefore=legacyCalls;
            check(driver.ReadMemory(frame)=="UNAVAILABLE"&&!frame.Physical.HasValue&&legacyCalls==legacyBefore,"corrupted EX version no fallback");badVersion=false;
            foreach(ulong[] values in new ulong[][]{new ulong[]{0,0,0},new ulong[]{8192,0,0},new ulong[]{8192,8193,1},new ulong[]{8192,8000,8001},new ulong[]{9007199254740992,8000,1}})
            {
                physicalBytes=values[0];allocatableBytes=values[1];availableBytes=values[2];frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadMemory(frame)=="UNAVAILABLE"&&!frame.Physical.HasValue,"partial or invalid memory rejected");
            }
            physicalBytes=8192;allocatableBytes=8000;
            foreach(ulong remaining in new ulong[]{0,8000})
            {
                availableBytes=remaining;frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadMemory(frame)=="OK"&&frame.Available==remaining,"full and empty allocatable memory");
            }
            frame=new Frame("UNAVAILABLE");FixtureIdentity=new Queue<bool>(new bool[]{false});int exBefore=exCalls;
            check(driver.ReadMemory(frame)=="DEVICE_CHANGED"&&exCalls==exBefore,"memory identity before query");
            frame=new Frame("UNAVAILABLE");FixtureIdentity=new Queue<bool>(new bool[]{true,false});
            check(driver.ReadMemory(frame)=="DEVICE_CHANGED"&&!frame.Physical.HasValue,"memory identity after query");
            driver.sharedSupport="OK";
            driver.sharedProperty=delegate(IntPtr adapter,uint property,UIntPtr size,IntPtr output)
            {check(property==15&&size.ToUInt64()==4,"physical count query");Marshal.WriteInt32(output,(int)physicalCount);return propertyStatus;};
            driver.sharedQuery=delegate(IntPtr adapter,uint state,UIntPtr inputSize,IntPtr input,UIntPtr outputSize,IntPtr output)
            {
                ++sharedCalls;check(state==2&&inputSize.ToUInt64()==8&&outputSize.ToUInt64()==16,"shared state ABI");
                check(Marshal.ReadInt32(input)==0&&Marshal.ReadInt32(input,4)==1,"shared type and sole node");
                Marshal.WriteInt64(output,unchecked((long)committed));Marshal.WriteInt64(output,8,unchecked((long)resident));return queryStatus;
            };
            foreach(ulong[] values in new ulong[][]{new ulong[]{0,0},new ulong[]{0,1},new ulong[]{2,1},new ulong[]{9007199254740991,9007199254740991}})
            {
                committed=values[0];resident=values[1];frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadShared(frame)=="OK"&&frame.SharedCommitted==committed&&frame.SharedResident==resident,"independent shared values including zero");
            }
            foreach(ulong[] values in new ulong[][]{new ulong[]{9007199254740992,0},new ulong[]{0,UInt64.MaxValue}})
            {
                committed=values[0];resident=values[1];frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadShared(frame)=="UNAVAILABLE"&&!frame.SharedCommitted.HasValue,"shared exact integer limit");
            }
            committed=0;resident=1;
            foreach(uint nodes in new uint[]{0,2,UInt32.MaxValue})
            {
                physicalCount=nodes;frame=new Frame("UNAVAILABLE");resetIdentity();int before=sharedCalls;
                check(driver.ReadShared(frame)=="UNSUPPORTED"&&sharedCalls==before,"multiple or unknown physical adapters not guessed");
            }
            physicalCount=1;propertyStatus=-1;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadShared(frame)=="UNAVAILABLE"&&!frame.SharedResident.HasValue,"physical property failure");propertyStatus=0;
            queryStatus=-1;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadShared(frame)=="UNAVAILABLE"&&!frame.SharedResident.HasValue,"shared query failure");queryStatus=0;
            driver.sharedSupport="UNSUPPORTED";frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadShared(frame)=="UNSUPPORTED","unsupported DXCore state");driver.sharedSupport="OK";
            frame=new Frame("UNAVAILABLE");FixtureIdentity=new Queue<bool>(new bool[]{true,true,false});
            check(driver.ReadShared(frame)=="DEVICE_CHANGED"&&!frame.SharedCommitted.HasValue,"shared identity after query");
            driver.utilization=delegate(IntPtr gpu,ref UtilizationData data)
            {
                ++utilCalls;check(data.Version==(72|0x10000)&&data.Domains.Length==8,"utilization ABI");
                for(int i=0;i<4;++i){data.Domains[i].Present=(mask&(1u<<i))!=0?3u:2u;data.Domains[i].Percentage=percent;}
                if(badUtilVersion)data.Version=0;return utilStatus;
            };
            foreach(uint present in new uint[]{0,1,2,4,8,15})
            {
                mask=present;frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadUtilization(frame)=="OK","partial domain call succeeds");
                for(int i=0;i<4;++i)check(frame.Utilization[i].HasValue==((mask&(1u<<i))!=0),"present bit independent of reserved flags");
            }
            mask=15;percent=100;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadUtilization(frame)=="OK"&&frame.Utilization[3]==100,"utilization 100 valid");
            percent=101;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadUtilization(frame)=="UNAVAILABLE"&&!frame.Utilization[0].HasValue,"bad percentage rejects category");
            mask=0;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadUtilization(frame)=="OK"&&!frame.Utilization[0].HasValue,"absent domain ignores undefined value");
            mask=15;percent=0;badUtilVersion=true;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadUtilization(frame)=="UNAVAILABLE","bad activity version");badUtilVersion=false;
            foreach(int failure in new int[]{-104,-1,-10})
            {
                utilStatus=failure;frame=new Frame("UNAVAILABLE");resetIdentity();
                check(driver.ReadUtilization(frame)==(failure==-104?"UNSUPPORTED":failure==-10?"DEVICE_CHANGED":"UNAVAILABLE"),"activity error classification");
            }
            utilStatus=0;frame=new Frame("UNAVAILABLE");FixtureIdentity=new Queue<bool>(new bool[]{true,false});
            check(driver.ReadUtilization(frame)=="DEVICE_CHANGED"&&!frame.Utilization[0].HasValue,"activity identity after query");
            NvidiaUtilizationQuery savedUtilization=driver.utilization;driver.utilization=null;frame=new Frame("UNAVAILABLE");resetIdentity();
            check(driver.ReadUtilization(frame)=="UNSUPPORTED"&&!frame.Utilization[0].HasValue,"missing activity API");driver.utilization=savedUtilization;
            resetIdentity();Frame combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="UNSUPPORTED"&&combined.MemoryStatus=="OK"&&combined.SharedStatus=="OK"&&combined.UtilizationStatus=="OK","missing thermal API preserves other features");
            driver.thermal=delegate(IntPtr gpu,uint index,ref ThermalSettings data){return -104;};
            resetIdentity();combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="UNSUPPORTED"&&combined.MemoryStatus=="OK"&&combined.UtilizationStatus=="OK","unsupported thermal sensor preserves memory and activity");
            driver.nvidiaStatus="UNSUPPORTED";resetIdentity();combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="UNSUPPORTED"&&combined.MemoryStatus=="UNSUPPORTED"&&combined.SharedStatus=="OK"&&combined.UtilizationStatus=="UNSUPPORTED","shared queries do not require NVIDIA support");
            driver.nvidiaStatus="OK";driver.memoryEx=null;driver.memoryLegacy=null;
            driver.thermal=delegate(IntPtr gpu,uint index,ref ThermalSettings data){data.Count=1;data.Sensors[0].Target=1;data.Sensors[0].CurrentTemp=42;return 0;};
            resetIdentity();combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="OK"&&combined.Temperature==42&&combined.MemoryStatus=="UNSUPPORTED"&&combined.UtilizationStatus=="OK","missing memory APIs preserve thermal and activity");
            driver.memoryEx=ex;driver.memoryLegacy=legacy;utilStatus=-10;resetIdentity();combined=driver.ReadFrame();
            check(combined.TemperatureStatus=="DEVICE_CHANGED"&&combined.MemoryStatus=="DEVICE_CHANGED"&&combined.SharedStatus=="DEVICE_CHANGED"&&combined.UtilizationStatus=="DEVICE_CHANGED","last category invalidation clears whole frame");
            check(!combined.Temperature.HasValue&&!combined.Physical.HasValue&&!combined.SharedCommitted.HasValue&&!combined.Utilization[0].HasValue,"late invalidation clears earlier values");
            FixtureIdentity=null;driver.Dispose();driver.Dispose();
            check(driver.ReadFrame().MemoryStatus=="UNAVAILABLE","disposed frame");
            check(Marshal.SizeOf(typeof(MemoryEx))==80&&Marshal.OffsetOf(typeof(MemoryEx),"Physical").ToInt32()==8&&Marshal.OffsetOf(typeof(MemoryEx),"Available").ToInt32()==40,"EX alignment and offsets");
            check(Marshal.SizeOf(typeof(MemoryLegacy))==32&&Marshal.OffsetOf(typeof(MemoryLegacy),"Available").ToInt32()==20,"legacy alignment and offsets");
            check(Marshal.SizeOf(typeof(UtilizationData))==72&&Marshal.SizeOf(typeof(UtilizationDomain))==8,"utilization alignment");
            return count;
        }
"@
$source=$source.Replace('    private sealed class Driver : IDisposable',$outer+[Environment]::NewLine+'    private sealed class Driver : IDisposable')
$source=$source.Replace('        private static readonly Guid FactoryId',$inner+[Environment]::NewLine+'        private static readonly Guid FactoryId')
$source=$source.Replace('            if (opened || disposed) return "UNAVAILABLE";','            ++FixtureOpenCalls; if (FixtureOpenStatus != null) { FixtureOpened.Set(); return FixtureOpenStatus; }'+[Environment]::NewLine+'            if (opened || disposed) return "UNAVAILABLE";')
$anchor='        private bool IdentityMatches()'+[Environment]::NewLine+'        {'
if (-not $source.Contains($anchor)) {$anchor='        private bool IdentityMatches()'+[char]10+'        {'}
if (-not $source.Contains($anchor)) {throw 'Missing identity fixture anchor'}
$source=$source.Replace($anchor,$anchor+[Environment]::NewLine+'            if (FixtureIdentity != null) return FixtureIdentity.Dequeue();')
Add-Type -TypeDefinition $source -Language CSharp
[ParallaxGpuTemperature]::PureFixtures()
[ParallaxGpuTemperature]::OwnProcessNameProbe()

[ParallaxGpuTemperature]::LifecycleFixture()

} finally {
[Environment]::CurrentDirectory = $gpuCheckOriginalDirectory
}
