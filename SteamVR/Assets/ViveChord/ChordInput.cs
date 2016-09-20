using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using WindowsInput.Native;

[System.CLSCompliant(false)]
[RequireComponent(typeof(SteamVR_TrackedObject))]
public class ChordInput : MonoBehaviour
{
    private static Dictionary<ulong, VirtualKeyCode> ChordMap
        = new Dictionary<ulong, VirtualKeyCode>
        {
            // Left Hand D-Pad - Movement
            {1, VirtualKeyCode.DOWN},
            {2, VirtualKeyCode.LEFT},
            {3, VirtualKeyCode.HOME},
            {4, VirtualKeyCode.RIGHT},
            {5, VirtualKeyCode.END},
            {6, VirtualKeyCode.UP},
            {7, VirtualKeyCode.ESCAPE},

            // Right Hand D-Pad - Editting Movements
            { 8, VirtualKeyCode.SPACE},
            {16, VirtualKeyCode.BACK},
            {32, VirtualKeyCode.TAB},
            // Right Center
            {56, VirtualKeyCode.RETURN},

            // R zoneBot + (L Clockwise)
            { 9, VirtualKeyCode.VK_A},
            {11, VirtualKeyCode.VK_B},
            {10, VirtualKeyCode.VK_C},
            {14, VirtualKeyCode.VK_D},
            {12, VirtualKeyCode.VK_E},
            {13, VirtualKeyCode.VK_F},
            {15, VirtualKeyCode.VK_G},

            // (R zoneBot+L) + (L Clockwise)
            {25, VirtualKeyCode.VK_H},
            {27, VirtualKeyCode.VK_I},
            {26, VirtualKeyCode.VK_J},
            {30, VirtualKeyCode.VK_K},
            {28, VirtualKeyCode.VK_L},
            {29, VirtualKeyCode.VK_M},
            {31, VirtualKeyCode.VK_N},

            // (R zoneL) + (L Clockwise)
            {17, VirtualKeyCode.VK_O},
            {19, VirtualKeyCode.VK_P},
            {18, VirtualKeyCode.VK_Q},
            {22, VirtualKeyCode.VK_R},
            {20, VirtualKeyCode.VK_S},
            {21, VirtualKeyCode.VK_T},
            {23, VirtualKeyCode.VK_U},

            // (R zoneL+R) + (L Clockwise)
            {49, VirtualKeyCode.VK_V},
            {51, VirtualKeyCode.VK_W},
            {50, VirtualKeyCode.VK_X},
            {54, VirtualKeyCode.VK_Y},
            {52, VirtualKeyCode.VK_Z},
        };

    enum ControllerHand { L, R }

    enum ChordButtonID
    {
        Pie_0_0,
        Pie_0_1,
        Pie_0_2,

        Pie_1_0,
        Pie_1_1,
        Pie_1_2,
    };

    class ChordMask
    {
        private Dictionary<ChordButtonID, ulong> masks;
        public readonly ulong All;

        public ChordMask(ChordButtonID[] inputs)
        {
            masks = new Dictionary<ChordButtonID, ulong>();

            foreach (ChordButtonID b in inputs)
            {
                ulong mask = 1ul << masks.Count;
                masks.Add(b, mask);
                All |= mask;
            }
        }

        public ulong For(ChordButtonID b)
        {
            return masks[b];
        }

        public string StringFor(ulong mask)
        {
            if (mask == 0) { return "[]"; }

            List<string> buttonsPressed = new List<string>();
            foreach (KeyValuePair<ChordButtonID, ulong> mapping in masks)
            {
                if ((mask & mapping.Value) == 0) { continue; }
                buttonsPressed.Add(mapping.Key.ToString());
            }

            return "[" + string.Join(",", buttonsPressed.ToArray()) + "]";
        }
    }

    // TODO: Implement 3-button support
    class TouchpadButtonMask
    {
        // If the location's distance from center is <= this radius then All buttons are pressed.
        const float centerZoneRadius = 0.35F;
        const float centerZoneRadius_sq = (centerZoneRadius * centerZoneRadius);

        // The Touchpad Circle is divided into 3 zones of equal size.
        private ulong maskZoneBot, maskZoneL, maskZoneR;

        // A Mask for all the Touchpad ButtonID's attached the Hand
        public readonly ulong All;

        public TouchpadButtonMask(int deviceIndex)
        {
            maskZoneBot = 1ul << (0 + (deviceIndex * 3));
            maskZoneL   = 1ul << (1 + (deviceIndex * 3));
            maskZoneR   = 1ul << (2 + (deviceIndex * 3));

            All = maskZoneBot | maskZoneL | maskZoneR;
        }

        public ulong MaskFor(Vector2 touch)
        {
            float touch_distance_sq = touch.sqrMagnitude;

            // Pressing All
            if (touch_distance_sq <= centerZoneRadius_sq)
            {
                return All;
            }

            // Calculate Angle difference from pi/2. Result will be within [0-pi]
            float theta = Mathf.Acos(touch.y / Mathf.Sqrt(touch_distance_sq));
            const float FourSixthsPI = 4 * Mathf.PI / 6;
            const float OneSixthsPI = Mathf.PI / 6;

            // Pressing ~North on Touchpad(returns L and R)
            if (theta <= OneSixthsPI)
            {
                return maskZoneL | maskZoneR;
            }

            // Pressing ~South on Touchpad(returns Bot)
            if (theta > (FourSixthsPI + OneSixthsPI))
            {
                return maskZoneBot;
            }

            // Cache which side(L or R) of the touchpad we're on
            ulong maskZone = touch.x <= 0 ? maskZoneL : maskZoneR;

            // Only pressing L or R zone
            if (theta <= (FourSixthsPI - OneSixthsPI))
            {
                return maskZone;
            }

            // Presing (L or R) with Bot zone
            return maskZoneBot | maskZone;
        }
    }

    class Device
    {
        static private ControllerHand HandForName(string name)
        {
            // TODO: Generalize this resolution of GameObject.name => enum value
            return name.Contains("Left") ? ControllerHand.L : ControllerHand.R;
        }

        private SteamVR_TrackedObject controller;

        // Mask Configuration
        // A Mapping of ChordButtonID's => Unique Mask Values
        public ChordMask mask { get; private set; }

        // Unique set of ChordButtonID's for the Device's Hand
        //public ChordButtonID trigger { get; private set; }
        public TouchpadButtonMask touchpad { get; private set; }

        public SteamVR_Controller.Device node
        {
            get { return SteamVR_Controller.Input((int)controller.index); }
        }

        public Device(SteamVR_TrackedObject controller)
        {
            this.controller = controller;

            // TODO: Add Runtime Configuration of ChordingButton's used
            mask = new ChordMask(new ChordButtonID[] {
                ChordButtonID.Pie_0_0,
                ChordButtonID.Pie_0_1,
                ChordButtonID.Pie_0_2,
                ChordButtonID.Pie_1_0,
                ChordButtonID.Pie_1_1,
                ChordButtonID.Pie_1_2,
            });

            ControllerHand hand = HandForName(controller.name);
            //trigger = (hand == ControllerHand.L ? ChordButtonID.Trigger_0 : ChordButtonID.Trigger_1);

            // TODO: Factor out index calculation
            touchpad = new TouchpadButtonMask((int)hand);

            Debug.Log("Mask Config: " + mask.StringFor(mask.All));
            Debug.Log(string.Join("\n", new[] {
                controller.name + " setup as " + hand.ToString(),
                //"Trigger  => " + trigger.ToString(),
                "Touchpad => " + mask.StringFor(touchpad.All),
            }));
        }
    }

    class ChordMachine
    {
        public enum State
        {
            Building,
            Playing,
            Played,
        }

        public enum InputEvent
        {
            TriggerPressed,
            TriggerReleased,

            TouchpadPressed,
            TouchpadValueModified,
            TouchpadReleased,

            ChordValueOutput,
        }

        private static WindowsInput.InputSimulator output = new WindowsInput.InputSimulator();

        private List<Device> devices = new List<Device>();
        private List<Device> fixedUpdate = new List<Device>();

        private ulong prevKeys = 0;
        private ulong chordKeys = 0;
        private State status = ChordMachine.State.Building;

        public void AddDevice(Device device)
        {
            devices.Add(device);
        }

        // Fan-In Entry Point for all Input Devices used for chording.
        public void FixedUpdate(Device device)
        {
            fixedUpdate.Add(device);
            SteamVR_Controller.Device node = device.node;

            // ## Update Phase - Additions to Chord Being Built
            //bool triggerDown = dev.GetTouch(SteamVR_Controller.ButtonMask.Trigger)
            //    || dev.GetTouchDown(SteamVR_Controller.ButtonMask.Trigger);
            bool touchpadDown = node.GetPress(SteamVR_Controller.ButtonMask.Touchpad)
                || node.GetPressDown(SteamVR_Controller.ButtonMask.Touchpad);

            // ### Update Trigger State
            //chordKeys = triggerDown ?
            //    chordKeys | device.mask.For(device.trigger) :
            //    chordKeys & ~device.mask.For(device.trigger);

            // ### Update Touchpad
            chordKeys &= ~device.touchpad.All;
            chordKeys = touchpadDown ?
                chordKeys | device.touchpad.MaskFor(node.GetAxis(Valve.VR.EVRButtonId.k_EButton_SteamVR_Touchpad)) :
                chordKeys;

            FixedUpdate();
        }

        // Used to generate a list of InputEvents that the current frame produced from a given device.
        private List<InputEvent> EventsFromUpdate(Device device)
        {
            ulong touchpadKeysDownPrev = (prevKeys & device.touchpad.All);
            ulong touchpadKeysDownNow = (chordKeys & device.touchpad.All);

            bool touchpadWasDownPrev = touchpadKeysDownPrev != 0;
            bool touchpadIsDownNow = touchpadKeysDownNow != 0;

            //ulong triggerMask = device.mask.For(device.trigger);
            //bool triggerDownPrev = (prevKeys & triggerMask) != 0;
            //bool triggerDownNow = (chordKeys & triggerMask) != 0;

            var events = new List<InputEvent>();

            if ((touchpadWasDownPrev && touchpadIsDownNow)
                && (touchpadKeysDownPrev != touchpadKeysDownNow))
            {
                events.Add(ChordMachine.InputEvent.TouchpadValueModified);
            }

            // Press Events
            //if (!triggerDownPrev && triggerDownNow)
            //{
            //    events.Add(ChordMachine.InputEvent.TriggerPressed);
            //}

            if (!touchpadWasDownPrev && touchpadIsDownNow)
            {
                events.Add(ChordMachine.InputEvent.TouchpadPressed);
            }

            // Release Events
            //if (triggerDownPrev && !triggerDownNow)
            //{
            //    events.Add(ChordMachine.InputEvent.TriggerReleased);
            //}

            if (touchpadWasDownPrev && !touchpadIsDownNow)
            {
                events.Add(ChordMachine.InputEvent.TouchpadReleased);
            }

            return events;
        }

        // A Mapping of Valid State Transistions
        private static State Transistion(State state, InputEvent inputEvent)
        {
            switch (state)
            {
                case State.Building:
                    if (inputEvent == InputEvent.TriggerReleased
                        || inputEvent == InputEvent.TouchpadReleased)
                    {
                        return State.Playing;
                    }
                    break;

                case State.Playing:
                    if (inputEvent == InputEvent.ChordValueOutput)
                    {
                        return State.Played;
                    }
                    break;

                case State.Played:
                    if (inputEvent == InputEvent.TriggerPressed
                        || inputEvent == InputEvent.TouchpadPressed
                        || inputEvent == InputEvent.TouchpadValueModified)
                    {
                        return State.Building;
                    }
                    break;
            }

            return state;
        }

        private void FixedUpdate()
        {
            // Fan-In once all devices have updated.
            if (fixedUpdate.Count != devices.Count) { return; }
            fixedUpdate.Clear();

            // No Events could have been generated if there was no change in chord key state.
            if (prevKeys == chordKeys) { return; }

            // Calculate all events generated this frame and apply them to our state.
            foreach (Device dev in devices)
            {
                foreach (InputEvent e in EventsFromUpdate(dev))
                {
                    status = Transistion(status, e);
                }
            }

            // Generate Output and Feedback
            if (status == ChordMachine.State.Playing)
            {
                simulateKeyForChord(prevKeys);
                status = Transistion(status, ChordMachine.InputEvent.ChordValueOutput);

                foreach (Device dev in devices)
                {
                    var node = dev.node;
                    //bool triggerDown = node.GetTouch(SteamVR_Controller.ButtonMask.Trigger)
                    //    || node.GetTouchDown(SteamVR_Controller.ButtonMask.Trigger);
                    bool touchpadDown = node.GetPress(SteamVR_Controller.ButtonMask.Touchpad)
                        || node.GetPressDown(SteamVR_Controller.ButtonMask.Touchpad);

                    //if (triggerDown)
                    //    node.TriggerHapticPulse(1000, Valve.VR.EVRButtonId.k_EButton_SteamVR_Trigger);
                    if (touchpadDown)
                        node.TriggerHapticPulse(1000, Valve.VR.EVRButtonId.k_EButton_SteamVR_Touchpad);
                }
            }

            prevKeys = chordKeys;
        }

        private void simulateKeyForChord(ulong chord)
        {
            VirtualKeyCode key;

            if (!ChordMap.TryGetValue(prevKeys, out key))
            {
                Debug.Log(string.Format("Unbound Chord Value({0})", prevKeys));
                return;
            }

            Debug.Log(string.Format("Output Chord Value({0}, {1}) : {2}", prevKeys, key, devices[0].mask.StringFor(prevKeys)));
            output.Keyboard.KeyPress(key);
        }
    }

    Device device;

    // Shared Button State between both hands
    static private ChordMachine chord = new ChordMachine();

    ChordInput()
    {
    }

    void Awake()
    {
        device = new Device(GetComponent<SteamVR_TrackedObject>());
        chord.AddDevice(device);
    }

    void FixedUpdate()
    {
        chord.FixedUpdate(device);
    }
}