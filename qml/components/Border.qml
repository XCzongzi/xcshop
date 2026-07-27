import QtQuick
import xcshop



Item{
    id:root
    property Window mainWindow
    property int margins: root.mainWindow.visibility === Window.Maximized? 0 : Constants.margins

    
      
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
            false : true
        x:root.margins
        y:root.margins
        width: 5
        height: root.mainWindow.height - 2*root.margins
        onPressed: root.mainWindow.startSystemResize(Qt.LeftEdge)
        cursorShape: Qt.SizeHorCursor
    }
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
            false : true
        x:root.mainWindow.width - root.margins
        y:root.margins
        width: 5
        height: root.mainWindow.height - 2*root.margins
        onPressed: root.mainWindow.startSystemResize(Qt.RightEdge)
        cursorShape: Qt.SizeHorCursor
    }
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
            false : true
        x:root.margins
        y:root.margins
        width: root.mainWindow.width - 2*root.margins
        height: 5
        onPressed: root.mainWindow.startSystemResize(Qt.TopEdge)
        cursorShape: Qt.SizeVerCursor
    }
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
            false : true
        x:root.margins
        y:root.mainWindow.height - root.margins
        width: root.mainWindow.width - 2*root.margins
        height: 5
        onPressed: root.mainWindow.startSystemResize(Qt.BottomEdge)
        cursorShape: Qt.SizeVerCursor
    }
    

//四个角的大小调整
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
                false : true
        x:root.margins
        y:root.mainWindow.height-5 - root.margins
        height: 5
        width: 5
        onPressed: root.mainWindow.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
        cursorShape: Qt.SizeBDiagCursor
    }
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
                false : true
        x:root.mainWindow.width-5 - root.margins
        y:root.mainWindow.height-5 - root.margins
        height: root.margins
        width: root.margins
        onPressed: root.mainWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
        cursorShape: Qt.SizeFDiagCursor
    }

    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
                false : true
        x:root.margins
        y:root.margins
        height: 5
        width: 5
        onPressed: root.mainWindow.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
        cursorShape: Qt.SizeFDiagCursor
    }
    MouseArea{
        visible: root.mainWindow.visibility === Window.Maximized? 
                false : true
        x:root.mainWindow.width-5 - root.margins
        y:root.margins
        height: 5
        width: 5
        onPressed: root.mainWindow.startSystemResize(Qt.TopEdge | Qt.RightEdge)
        cursorShape: Qt.SizeBDiagCursor
    }
}
