+++
title = "An async I/O reading note"
description = "A reading note"
date = 2022-06-19

[taxonomies]
categories = ["Note"]
tags = ["Rust"]
+++

This post is a study note based on video: [Async I/O in Depth: State Machines, Event Loops and Non-Blocking I/O System Calls](https://www.youtube.com/watch?v=_3LpJ6I-tzc)

## System Calls/ Stacks

- When you execute a software interrupt such as a syscall, the CPU will need to decide how to switch between user space / kernel space.

- During an interrupt it will

  - Save current state (registers for stack)

  - Process interrupt

  - Invoke kernel scheduling

  - Restore CPU context and return

- Each process is then composed of two stacks

  - Kernel/ User

- What you can access is dependent on the privilege level as defined by a protection ring

- CPU architectures will differ, but each ring is a cooperation between the OS and the CPU that the level will depend on the instruction set being executed

## Why is this relevant? To avoid extra work

- We want to avoid creating extra work for the CPU by either continuously checking whether operations are ready or completed

- CPU already handles hardware interrupts when working with the network for instance

- CPU/OS is interrupt/ event driven already in that it is constantly responding to events and switching contexts

- Event driven OS apis like **epoll**, **kqueue**, **io_uring** can allow us to **work with the OS** and coordinate when the interrupts happen without suspending our work

## Event Loop/ Event/ Queue Architectures

- A way to handle non-blocking I/O by ensuring that any normally blocking operation on a file descriptor (socket, fs..etc) would be instead monitored by the OS

- OS will create an event based on the activity we care about (read, accept, error, hangup..etc)

- OS event may either contain the results of the operation (completion model) or an event stating an operation may now be executing without blocking (readiness)

## poll()

- Single threaded and uses poll system call

- Multiplexes between requests by informing operating system which file descriptors to monitor and poll operations on them

- Each system call to poll will pass list of fds and will return with the number of changes that occurred

- By maintaining a state for each request and a series of callbacks to functions for updated file descriptors, a state machine can be implemented to progress each request to the next stage

- Requires passing along the file descriptors every time

- Lopping over fds to determine which events were triggered

- Limited in event scope (kinds of events)

- Memory overhead and performance bottlenecks
