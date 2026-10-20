/*
 * Copyright (C) 2014 The CyanogenMod Project
 * Copyright (C) 2026 KiroOS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.cyanogenmod.hardware;

import org.cyanogenmod.internal.util.FileUtils;

/*
 * Turns the capacitive Back and Recents keys off while the on-screen navigation bar is shown
 * (KiroOS Beta 5: Settings > Display > Navigation bar, live, no restart). The same control as
 * on the Note 5 (noblelte-common).
 */
public class KeyDisabler {

    private static final String CONTROL_PATH = "/sys/class/sec/sec_touchkey/input/enabled";

    public static boolean isSupported() {
        return FileUtils.isFileWritable(CONTROL_PATH);
    }

    public static boolean isActive() {
        return "0".equals(FileUtils.readOneLine(CONTROL_PATH));
    }

    public static boolean setActive(boolean state) {
        return FileUtils.writeLine(CONTROL_PATH, state ? "0" : "1");
    }
}
