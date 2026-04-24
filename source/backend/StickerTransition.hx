package backend;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.FlxState;

class StickerTransition extends MusicBeatSubstate
{
	public static var callback:Void->Void;

	var isTransIn:Bool = false;
	var stickerGroup:FlxSpriteGroup;

	static inline var div = 1 / 24;
	public static var olds:Array<FlxSprite> = [];

	static var timerTimer = 0.025;

	var destroyStickers = false;

	static var images:Array<String> = [];
	static var toBeat:Array<{song:String, image:String}> = [];
	static var stickerScale:Float = 0.5;
	static var soundPrefix:String = "keyClick";
	static var range:Int = 8;

	//In case it is reset
	public var imagePaths:Array<String> = [];

	public function new(isTransIs)
	{
		super();
		this.isTransIn = isTransIs;
	}

	override function create()
	{
		super.create();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		stickerGroup = new FlxSpriteGroup();
		add(stickerGroup);

		if (images.length == 0)
			parseStickers();

		if (isTransIn)
		{
			olds = [];
			imagePaths = images.copy();
			checkSongs();
			regenStickers();
		}
		else
		{
			degenStickers();
		}
	}

	function checkSongs()
	{
		var remove:Array<{song:String, image:String}> = [];

		for (beat in toBeat)
		{
			trace('Checking song: ${beat.song}');
			for (i in 0...Difficulty.list.length)
			{
				var song = Paths.formatToSongPath(beat.song);
				song = song.substring(0, song.length - 1) + Difficulty.getFilePath(i);
				trace('Path: $song');
				var score = Highscore.songScores.get(song);

				trace('Score: $score');

				if (!Math.isNaN(score) && score != null && score != 0 && score > 1000)
				{
					imagePaths.push(beat.image);
					if (!Paths.dumpExclusions.contains(beat.image))
					{
						Paths.dumpExclusions.push(beat.image);
						var bitmap = BitmapData.fromFile('assets/shared/images/${beat.image}.png');
						if (bitmap != null)
							Paths.cacheBitmap(beat.image, "shared", bitmap);
	
						trace('Song beaten: ${beat.song}');
					}
				}
			}
		}

		for (rev in remove)
		{
			toBeat.remove(rev);
		}
	}

	function parseStickers()
	{
		var path = Paths.txt("stickerPack", "shared");
		#if sys
		var file:String = (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		var file:String = (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end

		var lines:Array<String>;

		if (file != null)
			lines = file.split("\n");
		else
			return;

		for (line in lines)
		{
			line = StringTools.trim(line);

			if (line == "")
				continue;

			switch (line.charAt(0))
			{
				case "#":
					var firstSpace = line.indexOf(" ", 1);
					var songName = line.substr(1, firstSpace);
					var sticker = line.substr(firstSpace + 1).trim();
					toBeat.push({song: songName, image: 'stickers/$sticker'});
				case "$":
					try
					{
						var time = Std.parseFloat(line.substr(1).trim());
						if (!Math.isNaN(time))
							timerTimer = time;
					}
				case "%":
					try
					{
						var scale = Std.parseFloat(line.substr(1).trim());
						if (!Math.isNaN(scale))
							stickerScale = scale;
					}
				case "&":
					try
					{
						var range = Std.parseInt(line.substr(1).trim());
						if (!Math.isNaN(range))
							StickerTransition.range = range;
					}
				case "!":
					var prefix = line.substr(1);
					soundPrefix = prefix;
				default:
					images.push('stickers/$line');
					var path = 'assets/shared/images/stickers/$line.png';
					Paths.excludeAsset('stickers/$line');
					var bitmap = BitmapData.fromFile(path);
					if (bitmap != null)
						Paths.cacheBitmap('stickers/$line', "shared", bitmap);
			}
		}
	}

	function regenStickers()
	{
		// yes, stolen from V-Slice, sorry
		var xPos:Float = -100;
		var yPos:Float = -100;

		var i = 0;
		while (xPos <= FlxG.width)
		{
			i++;
			var sticker = new FlxSprite();
			if (imagePaths.length == 0)
			{
				sticker.makeGraphic(200, 200, FlxColor.RED);
			}
			else
			{
				var imagePath = FlxG.random.getObject(imagePaths);
				sticker.loadGraphic(imagePath, true, 1024, 1024);
				sticker.frame = FlxG.random.getObject(sticker.frames.frames);
				sticker.scale.set(stickerScale, stickerScale);
				sticker.updateHitbox();
			}
			sticker.visible = false;
			sticker.x = xPos;
			sticker.y = yPos;
			xPos += sticker.width * 0.3;
			if (xPos >= FlxG.width)
			{
				if (yPos <= FlxG.height)
				{
					xPos = -100;
					yPos += FlxG.random.float(70, 120);
				}
			}
			sticker.angle = FlxG.random.int(-60, 70);
			stickerGroup.add(sticker);
		}

		FlxG.random.shuffle(stickerGroup.members);

		for (i in 0...stickerGroup.members.length - 1)
		{
			var sticker = stickerGroup.members[i];
			olds.push(sticker);

			new FlxTimer().start(timerTimer * i, function(_)
			{
				sticker.visible = true;
				FlxG.sound.play(Paths.sound('stickers/$soundPrefix${FlxG.random.int(1, range)}'));

				var time = FlxG.random.int(0, 2);
				new FlxTimer().start(div * time, function(_)
				{
					sticker.scale.x = sticker.scale.y = FlxG.random.float(stickerScale - 0.03, stickerScale + 0.02);
				});
			});
		}

		var lastOne = stickerGroup.members[stickerGroup.members.length - 1];
		olds.push(lastOne);
		new FlxTimer().start(timerTimer * stickerGroup.members.length, function(_)
		{
			lastOne.visible = true;

			new FlxTimer().start(div * 2, function(_)
			{
				FlxG.signals.postStateSwitch.addOnce(function()
				{
					@:privateAccess
					var state = FlxG.game._state;

					for (sprite in olds)
					{
						state.add(sprite);
					}

					state.openSubState(new StickerTransition(false));
				});

				if (callback != null)
				{
					callback();
					callback = null;
				}
				else
				{
					close();
				}
			});
		});
	}

	function degenStickers()
	{
		destroyStickers = true;
		var oldUpd = _parentState.persistentUpdate;
		_parentState.persistentUpdate = false;

		if (olds.length == 0)
		{
			_parentState.persistentUpdate = oldUpd;
			close();
			return;
		}

		var i = olds.length;
		var x = 0;
		while (i > 1) {
			i--;
			var i = i;
			new FlxTimer().start(timerTimer * x, function(_)
			{
				FlxG.sound.play(Paths.sound('stickers/$soundPrefix${FlxG.random.int(1, range)}'));
				olds[i].exists = false;
			});
			x++;
		}

		x++;
		new FlxTimer().start(timerTimer * x, function(_)
		{
			olds[0].visible = false;
			_parentState.persistentUpdate = oldUpd;
			olds = [];
			close();
		});
		
		MusicBeatState.stickerTrans = false;
	}

	override function close()
	{
		super.close();

		if (callback != null)
		{
			callback();
			callback = null;
		}
	}

	override function destroy()
	{
		if (!destroyStickers)
			stickerGroup.clear();
		super.destroy();
	}
}
