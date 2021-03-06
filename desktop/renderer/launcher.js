import reactDOM from 'react-dom'
import React, {Component} from 'react'
import {Provider} from 'react-redux'
import RemoteStore from './remote-store.desktop'
import Menubar from '../shared/menubar'
import {ipcLogsRenderer} from '../app/console-helper'
import hello from '../shared/util/hello'
import {setupContextMenu} from '../app/menu-helper'
import loadPerf from '../shared/util/load-perf'
import {remote} from 'electron'

ipcLogsRenderer()
hello(process.pid, 'Menubar', process.argv, __VERSION__) // eslint-disable-line no-undef

if (module.hot) {
  module.hot.accept()
}

const store = new RemoteStore({})

class RemoteMenubar extends Component {
  constructor () {
    super()
    loadPerf()
  }
  render () {
    return (
      <Provider store={store}>
        <Menubar />
      </Provider>
    )
  }
}

reactDOM.render(React.createElement(RemoteMenubar), document.getElementById('root'))
setupContextMenu(remote.getCurrentWindow())
