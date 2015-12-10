package IHM;

import Config.Config;
import Settings.SettingsFrame;

/**
 * @author Chris Foulon
 * Model the BCBToolBox which will open different tools of the software
 * 
 * @inv
 * 	getWD() != null && !getWD().equals("") && 
 * 	getLesionsPath() != null && getLesionsDir() != null &&
 * 	getTractsPath() != null && getTractsDir() != null &&
 * 	getResultPath() != null && getResultDir() != null &&
 * 	getConfig() != null && getSettings() != null
 * 
 * @cons
 * $DESC$ BCBToolBox with a working directory wd
 *     $ARGS$ String wd
 *     $PRE$
 *         wd != null && !wd.equals("")
 *     $POST$
 *         getWD().equals(wd)
 * 
 *
 */

public interface BCBToolKit {
	//Dimensions
	public static final int FRAME_WIDTH = 310;
	public static final int FRAME_HEIGHT = 410;
	public static final int LINE_HEIGHT = 20;
	int INFRAME_PADDING = 20;
	
    // SETTERS
    //Just settings
    /**
     * Open the settings frame
     * @post
     * 		getSettings.isVisible()
     */
    void openSettings();
    
    // GETTERS    
    /**
     * Return the SettingsFrame
     */
    SettingsFrame getSettings();
    
    /**
     * Actual Config of this ToolBox
     */
    Config getConfig();
}
