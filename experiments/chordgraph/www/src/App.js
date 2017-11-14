import React, { Component } from 'react';
import logo from './logo.svg';
import './App.css';

class App extends Component {
  constructor() {
    super();
    this.state = {};
  }

  componentDidMount() {
    const socket = new WebSocket("ws://localhost:3001/model");
    socket.onopen = event => this.setState({ onopen: event });
    socket.onmessage = msg => this.setState({ msg, model: msg.data });
    socket.onerror = msg => this.setState({ error: msg });

    this.setState({ socket });
  }

  render() {
    const { model } = this.state;
    return (
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <h1 className="App-title">Welcome to React</h1>
        </header>
        <p className="App-intro">
          {model && model}
        </p>
      </div>
    );
  }
}

export default App;
