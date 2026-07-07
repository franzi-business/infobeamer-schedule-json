var config = {
  props: ['config'],
  template: `
    <div>
      <h4>Frab Plugin</h4>
      <div class='row'>
        <div class='col-xs-6'>
          Display Mode<br/>
          <select class='btn btn-default' v-model="mode">
            <option value="all_talks">All Talks</option>
            <option value="next_talk">Next Talk</option>
            <option value="room">Room Name</option>
            <option value="day">Day</option>
            <option value="clock">Clock</option>
            <option value="info">Info text</option>
          </select>
        </div>
        <div class='col-xs-3'>
          Text Colour<br/>
          <input
            type="color"
            v-model="color"
            class='form-control'/>
        </div>
        <div class='col-xs-3'>
          Font Size<br/>
          <input
            type="number"
            class='form-control'
            v-model="font_size" />
        </div>
      </div>
      <template v-if='mode == "all_talks"'>
        <h4>All Talks options</h4>
        <div class='row'>
          <div class='col'>
            <input
              type="checkbox"
              v-model="all_speakers"
              class='form-check-input'/>
            Show speaker names
          </div>
        </div>
        <div class='row'>
          <div class='col'>
            Proposal Type Filter<br/>
            <input
              type="text"
              v-model="proposal_type_filter"
              class='form-control'/>
            Proposal Type Filter accepts one or more proposal types, separated by <code>;</code>. Leaving this empty means showing all proposal types. Use ! to invert
          </div>
        </div>
      </template>
      <template v-if='mode == "next_talk"'>
        <h4>Next Talk options</h4>
        <div class='row'>
          <div class='col-xs-6'>
            <input
              type="checkbox"
              v-model="next_abstract"
              class='form-check-input'/>
            Show abstract
          </div>
          <div class='col-xs-6'>
            <input
              type="checkbox"
              v-model="next_track_text"
              class='form-check-input'/>
            Show track name instead of coloured bar
          </div>
        </div>
      </template>
      <template v-if='mode == "room"'>
        <h4>Room options</h4>
        <div class='row'>
          <div class='col-xs-6'>
            Alignment<br/>
            <select class='btn btn-default' v-model="room_align">
              <option value="left">Align left</option>
              <option value="center">Align centered</option>
              <option value="right">Align right</option>
            </select>
          </div>
          <div class='col-xs-6'>
            <input
              type="checkbox"
              v-model="room_animate"
              class='form-check-input'/>
            Fade in and out
          </div>
        </div>
      </template>
      <template v-if='mode == "clock"'>
        <h4>Clock options</h4>
        <div class='row'>
          <div class='col-xs-6'>
            Alignment<br/>
            <select class='btn btn-default' v-model="clock_align">
              <option value="left">Align left</option>
              <option value="center">Align centered</option>
              <option value="right">Align right</option>
            </select>
          </div>
          <div class='col-xs-6'>
            <input
              type="checkbox"
              v-model="clock_animate"
              class='form-check-input'/>
            Fade in and out
          </div>
        </div>
      </template>
      <template v-if='mode == "day"'>
        <h4>Day options</h4>
        <div class='row'>
          <div class='col-xs-6'>
            Alignment<br/>
            <select class='btn btn-default' v-model="day_align">
              <option value="left">Align left</option>
              <option value="center">Align centered</option>
              <option value="right">Align right</option>
            </select>
          </div>
          <div class='col-xs-6'>
            <input
              type="checkbox"
              v-model="day_animate"
              class='form-check-input'/>
            Fade in and out
          </div>
        </div>
        <div class='row'>
          <div class='col'>
            Format<br/>
            <input
              type="text"
              v-model="day_template"
              placeholder="Template: 'Day %s'"
              class='form-control'/>
          </div>
        </div>
      </template>
      <template v-if='mode == "info"'>
        <h4>Info options</h4>
        <div class='row'>
          <div class='col-xs-6'>
            Text Alignment<br/>
            <select class='btn btn-default' v-model="info_align">
              <option value="left">Align left</option>
              <option value="center">Align centered</option>
              <option value="right">Align right</option>
            </select>
          </div>
          <div class='col-xs-3'>
            Info source<br/>
            <select class='btn btn-default' v-model="info_text_source">
              <option value="a">Text A</option>
              <option value="b">Text B</option>
              <option value="image_a">Image A</option>
              <option value="image_b">Image B</option>
            </select>
          </div>
          <div class='col-xs-3'>
            <input
              type="checkbox"
              v-model="info_animate"
              class='form-check-input'/>
            Fade in and out
          </div>
        </div>
      </template>
    </div>
  `,
  computed: {
    mode: ChildTile.config_value('mode', 'all_talks'),
    color: ChildTile.config_value('color', '#ffffff'),
    font_size: ChildTile.config_value('font_size', 70, parseInt),

    all_speakers: ChildTile.config_value('all_speakers', true),
    proposal_type_filter: ChildTile.config_value('proposal_type_filter', ''),

    next_abstract: ChildTile.config_value('next_abstract', false),
    next_track_text: ChildTile.config_value('next_track_text', false),

    room_align: ChildTile.config_value('room_align', 'left'),
    room_animate: ChildTile.config_value('room_animate', true),

    clock_align: ChildTile.config_value('clock_align', 'left'),
    clock_animate: ChildTile.config_value('clock_animate', false),

    day_align: ChildTile.config_value('day_align', 'left'),
    day_template: ChildTile.config_value('day_template', 'Day %d'),
    day_animate: ChildTile.config_value('day_animate', false),

    info_align: ChildTile.config_value('info_align', 'left'),
    info_animate: ChildTile.config_value('info_animate', true),
    info_text_source: ChildTile.config_value('info_text_source', 'a'),
  }
}

ChildTile.register({
  config: config,
});
