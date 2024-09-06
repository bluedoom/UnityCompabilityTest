using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;
using static Assets.Benchmarker;

namespace Assets
{
    internal class Benchmarker
    {

        public enum Level
        {
            None = 0,
            LOW = 1,
            MEDIUM = 2,
            HIGH = 3,
        }

        const int LEN = 1024 * 1024;
        Vector4[] vector4Array = new Vector4[LEN];
        Vector3Int[] vector3Array = new Vector3Int[LEN];
        public void Prepare()
        {
            for (int i = 0; i < LEN; i++)
            {
                vector3Array[i] = new Vector3Int(i + 1, i + 1, i + 1);
                vector4Array[i] = new Vector4(i + 1, i + 1, i + 1, i + 1);
            }
            GC.Collect();
        }

        public static float GetPi(int end)
        {
            float sum = 0;
            for (int i = 1; i < end; i++)
            {
                if (i % 2 == 0)
                    sum -= (1f / ((i * 2) - 1));
                else
                    sum += (1f / ((i * 2) - 1));
            }
            return sum * 4;
        }
        public static long Sum(int end)
        {
            long sum = 0;
            for (int i = 1; i < end; i++)
            {
                if (i % 2 == 0)
                    sum -= ((i * 2) - 1) * i;
                else
                    sum += ((i * 2) - 1) * i;
            }
            return sum;
        }

        public static Level GetLevel(out long timeRank, out Level timeLevel, out Level socLevel)
        {
            socLevel = GetPerformanceLevel(out timeRank, out timeLevel);
            return socLevel == Level.None ? timeLevel : socLevel;
        }
        static Level ToLevel(long timeRank)
        {
            const Level LOW = Level.LOW;
            const Level MEDIUM = Level.MEDIUM;
            const Level HIGH = Level.HIGH;
            Level level2;
            if (timeRank < 70000)
            {
                level2 = HIGH;
            }
            else if (timeRank < 105000)
            {
                level2 = MEDIUM;
            }
            else level2 = LOW;
            return level2;
        }
        static Level GetPerformanceLevel(out long timeRank, out Level level2)
        {
            const Level LOW = Level.LOW;
            const Level MEDIUM = Level.MEDIUM;
            const Level HIGH = Level.HIGH;
            #region 通用
            var bench = new Benchmarker();
            bench.Prepare();
            bench.Run();
            timeRank = bench.Run();
            level2 = ToLevel(timeRank);
            #endregion
            var gpuName = SystemInfo.graphicsDeviceName;
            #region 高通
            // e.g. "Adreno (TM) 630"
            if (gpuName.StartsWith("adreno", StringComparison.OrdinalIgnoreCase))
            {
                var gpuType = gpuName.Substring("Adreno (TM) ".Length);
                if (int.TryParse(gpuType, out var gpuTypeInt))
                {
                    switch (gpuType[0])
                    {
                        //case '2':
                        //case '3':
                        //case '4':
                        //    return LOW; // too old no support
                        case '5':
                            {
                                if (gpuTypeInt >= 540) return MEDIUM;
                                else return LOW;
                            }
                        case '6':
                            {
                                if (gpuTypeInt >= 650) return HIGH;  //865 870
                                //else if (gpuTypeInt == 644) return MEDIUM; // 7 gen1
                                //else if (gpuTypeInt >= 640) return MEDIUM; // 855
                                //else if (gpuTypeInt >= 630) return MEDIUM; // 845
                                else if (gpuTypeInt >= 619) return MEDIUM; // 480 750g
                                else return LOW;
                            }
                        case '7':
                            {
                                if (gpuTypeInt >= 730) return HIGH; // 8 gen1
                                else if (gpuTypeInt >= 720) return MEDIUM; // 7+ Gen 2
                                else return LOW;
                            }
                        default:
                            {
                                // future soc
                                if (gpuType.Length > 1)
                                {
                                    var performance = gpuType[1];
                                    if (performance >= '3') return HIGH;
                                    else if (performance >= '2') return MEDIUM;
                                    else return LOW;
                                }
                                break;
                            }
                    }
                }
                UnityEngine.Debug.LogError($"Unknow Adreno GPU: {gpuName}");
            }
            #endregion
            return Level.None;
        }

        public static long JustCPUBench(out Level level, out double happy)
        {
            Stopwatch sw = new Stopwatch();
            sw.Start();
            var a = GetPi(1024 * 1024 * 8);
            var b = Sum(1024 * 1024 * 4);
            happy = a + b;
            sw.Stop();
            var timeScore = 4 * sw.ElapsedTicks * (1000L * 1000L ) / Stopwatch.Frequency;
            level = ToLevel(timeScore);
            return timeScore;
        }

        public long Run()
        {
            var sw = Runimpl();
            return sw.ElapsedTicks * (1000L * 1000L) / Stopwatch.Frequency;
        }
        Stopwatch Runimpl()
        {
            Stopwatch sw = new Stopwatch();
            sw.Start();
            System.Random rnd = new System.Random(114514);
            int Next()
            {
                return rnd.Next(LEN - 1);
            }
            for (int i = 0; i < LEN / 4; i++)
            {
                var idx = Next();
                var len = vector3Array[i].x + vector3Array[idx].y + vector3Array[i].z;
                idx = Next();
                var p = GetPi(len % 64);
                vector4Array[idx] *= p;
            }
            sw.Stop();
            return sw;
        }
    }
}
